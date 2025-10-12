// File: lib/features/user_app/payment_gateway/bloc/checkout_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';

import '../../../../shared/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../model/payment_models.dart';
import '../repository/razorpay_payment_repository.dart';
import '../repository/cod_payment_repository.dart';
import '../../cart/data/repository/cart_repository.dart';
import '../../data/repositories/booking_repository.dart';

import 'checkout_event.dart';
import 'checkout_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../cart/data/models/cart_item_model.dart';

/// CheckoutBloc orchestrates UI -> local DB -> Firestore -> payment flows.
/// Why: keep flows testable, decoupled and offline-friendly.
class CheckoutBloc extends Bloc<CheckoutEvent, CheckoutState> {
  final OrderRepository _orderRepo;
  final RazorpayPaymentRepository _razorpayRepo;
  final CodPaymentRepository _codRepo;
  final BookingRepository _bookingRepo;
  final CartRepository _cartRepo;
  final Future<String?> Function() _getCurrentUserId;

  CheckoutBloc({
    required OrderRepository orderRepo,
    required RazorpayPaymentRepository razorpayRepo,
    required CodPaymentRepository codRepo,
    required CartRepository cartRepo,
    required BookingRepository bookingRepo,
    required Future<String?> Function() getCurrentUserId,
  })  : _orderRepo = orderRepo,
        _razorpayRepo = razorpayRepo,
        _codRepo = codRepo,
        _bookingRepo = bookingRepo,
        _cartRepo = cartRepo,
        _getCurrentUserId = getCurrentUserId,
        super(const CheckoutState()) {
    on<CheckoutSubmitted>(_onCheckoutSubmitted);
  }

  Future<void> _onCheckoutSubmitted(CheckoutSubmitted event, Emitter<CheckoutState> emit) async {
    emit(state.copyWith(isInProgress: true, errorMessage: null, successMessage: null));
    try {
      final userId = await _getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        emit(state.copyWith(isInProgress: false, errorMessage: 'Please log in to place an order.'));
        return;
      }

      // Generate deterministic daily order number (YYYYMMDD + 5-digit suffix)
      String orderNumber;
      try {
        orderNumber = await _orderRepo.generateOrderNumber();
      } catch (e) {
        debugPrint('[CheckoutBloc] failed to generate orderNumber via repo: $e');
        // Fallback to a timestamp-based ORD id to avoid blocking checkout
        final now = DateTime.now().toUtc();
        orderNumber = 'ORD${now.millisecondsSinceEpoch}${now.microsecond % 1000}';
      }

      // Convert UI items to CartItemModel as cartItem if already in that shape this is a no-op.
      final itemsModel = event.request.items.map((i) {
        if (i is CartItemModel) return i;
        final json = (i as dynamic).toJson() as Map<String, dynamic>;
        return CartItemModel.fromJson(json);
      }).toList();

      final order = OrderModel(
        userId: userId,
        orderNumber: orderNumber,
        items: itemsModel,
        subtotal: event.request.totalAmount, // assume subtotal ~ total for simplicity
        discount: 0,
        total: event.request.totalAmount,
        paymentMethod: event.paymentMethod,
        paymentId: null,
        userName: event.request.userName,
        userEmail: event.request.userEmail,
        userPhone: event.request.userPhone,
        userAddress: event.request.userAddress, // include address from request
        createdAt: Timestamp.now(),
      );

      // Create local order only (do NOT upload remotely yet). We'll upload
      // after payment confirmation (Razorpay) or COD confirmation to avoid
      // creating Firestore documents for incomplete/abandoned checkouts.
      final savedLocal = await _orderRepo.createOrder(order, uploadRemote: false);

      // If Razorpay flow
      if (event.paymentMethod == 'razorpay') {
        debugPrint('[CheckoutBloc] Starting Razorpay payment for orderNumber=$orderNumber total=${event.request.totalAmount}');
        final localOnly = savedLocal; // localOnly alias
        final res = await _razorpayRepo.processPayment(event.request);
        debugPrint('[CheckoutBloc] Razorpay result for orderNumber=$orderNumber: $res');
        if (res is PaymentSuccess) {
          // update local-only order with payment info and mark success
          final updated = localOnly.copyWith(paymentId: res.paymentId, paymentStatus: 'success');
          await _orderRepo.updateLocalOrder(updated);
          String? remoteId;
          try {
            // Attempt to upload the paid order to Firestore now that payment succeeded
            remoteId = await _orderRepo.uploadOrder(updated);
          } catch (e) {
            debugPrint('[CheckoutBloc] uploadOrder threw after Razorpay: $e');
            remoteId = null;
          }

          // Clear cart locally regardless of remote upload success, but surface messages accordingly
          await _cartRepo.clearCart();
          try {
            await _bookingRepo.createBooking(updated);
          } catch (_) {}

          if (remoteId != null) {
            emit(state.copyWith(isInProgress: false, successMessage: 'Payment successful and order synced.'));
          } else {
            emit(state.copyWith(isInProgress: false, successMessage: 'Payment successful. Order will be uploaded when online.'));
          }
          return;
        } else if (res is PaymentFailure) {
          // mark local as failed
          if (localOnly.localId != null) {
            await _orderRepo.markLocalOrderFailed(localOnly.localId!, reason: res.message);
          }
          emit(state.copyWith(isInProgress: false, errorMessage: 'Payment failed: ${res.message}'));
          return;
        }
      } else {
        // COD
        final r = await _codRepo.processCod(event.request);
        if (r is PaymentSuccess) {
          // COD succeeded from app perspective (order accepted) — payment remains pending until delivery.
          final updated = savedLocal.copyWith(paymentStatus: 'pending', orderStatus: 'pending');
          await _orderRepo.updateLocalOrder(updated);
          String? remoteId;
          try {
            // Upload now that user confirmed COD
            remoteId = await _orderRepo.uploadOrder(updated);
          } catch (e) {
            debugPrint('[CheckoutBloc] uploadOrder threw (COD): $e');
            remoteId = null;
          }
          debugPrint('[CheckoutBloc] COD order localId=${savedLocal.localId} remoteId=$remoteId');
          // Ensure any remaining unsynced orders are uploaded promptly
          try {
            await _orderRepo.syncUnsynced();
            debugPrint('[CheckoutBloc] syncUnsynced called after COD');
          } catch (e) {
            debugPrint('[CheckoutBloc] syncUnsynced failed: $e');
          }
          await _cartRepo.clearCart();
          try {
            await _bookingRepo.createBooking(updated);
          } catch (_) {}
          if (remoteId != null) {
            emit(state.copyWith(isInProgress: false, successMessage: 'Order placed (COD) and synced.'));
          } else {
            emit(state.copyWith(isInProgress: false, successMessage: 'Order placed (COD). Will sync when online.'));
          }
          return;
        }
      }

      emit(state.copyWith(isInProgress: false));
    } catch (e) {
      emit(state.copyWith(isInProgress: false, errorMessage: e.toString()));
    }
  }
}
