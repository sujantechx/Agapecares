// File: lib/features/user_app/payment_gateway/bloc/checkout_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';


import '../../../../../core/models/cart_item_model.dart';
import '../../../../../core/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../model/payment_models.dart';
import '../repository/razorpay_payment_repository.dart';
import '../repository/cod_payment_repository.dart';
import '../../cart/data/repository/cart_repository.dart';
import '../../data/repositories/booking_repository.dart';

import 'checkout_event.dart';
import 'checkout_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


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

      // Prefer Firestore as primary storage on confirmed checkouts. Do not save
      // a local-only order upfront to avoid duplicate remote documents.
      // For Razorpay we will create the remote order only after payment success.
      // For COD we create the remote order immediately since the user confirmed.
      if (event.paymentMethod == 'razorpay') {
        debugPrint('[CheckoutBloc] Starting Razorpay payment for orderNumber=$orderNumber total=${event.request.totalAmount}');
        final res = await _razorpayRepo.processPayment(event.request);
        debugPrint('[CheckoutBloc] Razorpay result for orderNumber=$orderNumber: $res');
        if (res is PaymentSuccess) {
          // Build order with payment details and create remote doc (preferred)
          final paidOrder = order.copyWith(paymentId: res.paymentId, paymentStatus: 'success');
          OrderModel savedRemote;
          try {
            savedRemote = await _orderRepo.createOrder(paidOrder, uploadRemote: true);
          } catch (e) {
            debugPrint('[CheckoutBloc] createOrder(uploadRemote:true) failed after Razorpay: $e');
            // Fallback: try uploadOrder on a local save
            final fallback = await _orderRepo.createOrder(paidOrder, uploadRemote: false);
            try {
              await _orderRepo.uploadOrder(fallback);
            } catch (_) {}
            savedRemote = fallback;
          }

          // Clear cart and create booking
          await _cartRepo.clearCart();
          try {
            await _bookingRepo.createBooking(savedRemote);
          } catch (_) {}

          emit(state.copyWith(isInProgress: false, successMessage: 'Payment successful and order processed.'));
          return;
        } else if (res is PaymentFailure) {
          emit(state.copyWith(isInProgress: false, errorMessage: 'Payment failed: ${res.message}'));
          return;
        }
      } else {
        // COD: user confirmed cash-on-delivery - create remote order now
        final r = await _codRepo.processCod(event.request);
        if (r is PaymentSuccess) {
          OrderModel savedRemote;
          try {
            savedRemote = await _orderRepo.createOrder(order, uploadRemote: true);
          } catch (e) {
            debugPrint('[CheckoutBloc] createOrder(uploadRemote:true) failed (COD): $e');
            // fallback to local save
            savedRemote = await _orderRepo.createOrder(order, uploadRemote: false);
            try {
              await _orderRepo.syncUnsynced();
            } catch (_) {}
          }

          await _cartRepo.clearCart();
          try {
            await _bookingRepo.createBooking(savedRemote);
          } catch (_) {}

          emit(state.copyWith(isInProgress: false, successMessage: 'Order placed (COD).'));
          return;
        }
      }

      emit(state.copyWith(isInProgress: false));
    } catch (e) {
      emit(state.copyWith(isInProgress: false, errorMessage: e.toString()));
    }
  }
}
