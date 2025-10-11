// File: lib/features/user_app/payment_gateway/bloc/checkout_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';

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
  final Future<String> Function() _getCurrentUserId;

  CheckoutBloc({
    required OrderRepository orderRepo,
    required RazorpayPaymentRepository razorpayRepo,
    required CodPaymentRepository codRepo,
    required CartRepository cartRepo,
    required BookingRepository bookingRepo,
    required Future<String> Function() getCurrentUserId,
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
      // Convert UI items to CartItemModel as cartItem if already in that shape this is a no-op.
      final itemsModel = event.request.items.map((i) {
        if (i is CartItemModel) return i;
        final json = (i as dynamic).toJson() as Map<String, dynamic>;
        return CartItemModel.fromJson(json);
      }).toList();

      final order = OrderModel(
        userId: userId,
        items: itemsModel,
        subtotal: event.request.totalAmount, // assume subtotal ~ total for simplicity
        discount: 0,
        total: event.request.totalAmount,
        paymentMethod: event.paymentMethod,
        paymentId: null,
        userName: event.request.userName,
        userEmail: event.request.userEmail,
        userPhone: event.request.userPhone,
        userAddress: '', // pass from UI if available
        createdAt: Timestamp.now(),
      );

      // Save locally and get localId
      final savedLocal = await _orderRepo.createOrder(order);

      // If Razorpay flow
      if (event.paymentMethod == 'razorpay') {
        final res = await _razorpayRepo.processPayment(event.request);
        if (res is PaymentSuccess) {
          // update local order with paymentId and successful status
          final updated = savedLocal.copyWith(paymentId: res.paymentId, orderStatus: 'success');
          await _orderRepo.updateLocalOrder(updated);
          // try upload immediately
          final uploaded = await _orderRepo.uploadOrder(updated);

          if (uploaded) {
            // Clear cart locally after successful order
            await _cartRepo.clearCart();
            // also create a booking document (mirror orders collection or separate bookings collection)
            try {
              await _bookingRepo.createBooking(updated);
            } catch (_) {}
            emit(state.copyWith(isInProgress: false, successMessage: 'Payment successful and order synced.'));
          } else {
            await _cartRepo.clearCart();
            try {
              await _bookingRepo.createBooking(updated);
            } catch (_) {}
            emit(state.copyWith(isInProgress: false, successMessage: 'Payment successful. Order will be uploaded when online.'));
          }
          return;
        } else if (res is PaymentFailure) {
          // mark local as failed
          if (savedLocal.localId != null) {
            await _orderRepo.markLocalOrderFailed(savedLocal.localId!, reason: res.message);
          }
          emit(state.copyWith(isInProgress: false, errorMessage: 'Payment failed: ${res.message}'));
          return;
        }
      } else {
        // COD
        final r = await _codRepo.processCod(event.request);
        if (r is PaymentSuccess) {
          // set status to success and upload
          final updated = savedLocal.copyWith(orderStatus: 'success');
          await _orderRepo.updateLocalOrder(updated);
          final uploaded = await _orderRepo.uploadOrder(updated);
          if (uploaded) {
            await _cartRepo.clearCart();
            try {
              await _bookingRepo.createBooking(updated);
            } catch (_) {}
            emit(state.copyWith(isInProgress: false, successMessage: 'Order placed (COD) and synced.'));
          } else {
            await _cartRepo.clearCart();
            try {
              await _bookingRepo.createBooking(updated);
            } catch (_) {}
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
