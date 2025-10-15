// File: lib/features/user_app/payment_gateway/bloc/checkout_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import '../../../../../core/models/cart_item_model.dart';
import '../../../../../core/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../model/payment_models.dart';
import '../repository/razorpay_payment_repository.dart';
import '../repository/cod_payment_repository.dart';
import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';
import '../../data/repositories/booking_repository.dart';

import 'checkout_event.dart';
import 'checkout_state.dart';


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
        final dynamic maybeJson = (i as dynamic);
        Map<String, dynamic> json;
        try {
          json = (maybeJson.toJson() as Map<String, dynamic>);
        } catch (_) {
          json = Map<String, dynamic>.from(maybeJson as Map);
        }
        return CartItemModel.fromMap(json);
      }).toList();

      // Determine user address: prefer explicit request, then local session, then Firestore user doc
      String? effectiveAddress;
      final reqAddress = event.request.userAddress.trim().isEmpty ? null : event.request.userAddress.trim();
      if (reqAddress != null && reqAddress.isNotEmpty) {
        effectiveAddress = reqAddress;
      }

      // Helper: safely extract a string address from a dynamic entry which may be a String or Map
      String? extractAddress(dynamic entry) {
        if (entry == null) return null;
        if (entry is String) return entry;
        if (entry is Map) {
          final a = entry['address'];
          if (a is String) return a;
        }
        return null;
      }

      // Try session-based address if we don't have one yet
      if (effectiveAddress == null || effectiveAddress.isEmpty) {
        try {
          final session = SessionService();
          final su = session.getUser();
          if (su != null && su.addresses != null && su.addresses!.isNotEmpty) {
            final addrCandidate = extractAddress(su.addresses!.first);
            if (addrCandidate != null && addrCandidate.isNotEmpty) effectiveAddress = addrCandidate;
          }
        } catch (_) {
          // ignore and try Firestore next
        }
      }

      // Try Firestore user doc as a final fallback
      if (effectiveAddress == null || effectiveAddress.isEmpty) {
        try {
          final firebaseUser = FirebaseAuth.instance.currentUser;
          final uidForAddress = firebaseUser?.uid ?? userId;
          if (uidForAddress != null && uidForAddress.isNotEmpty) {
            final doc = await FirebaseFirestore.instance.collection('users').doc(uidForAddress).get();
            if (doc.exists) {
              final data = doc.data();
              if (data != null && data['addresses'] is List && (data['addresses'] as List).isNotEmpty) {
                final addrCandidate = extractAddress((data['addresses'] as List).first);
                if (addrCandidate != null && addrCandidate.isNotEmpty) effectiveAddress = addrCandidate;
              }
            }
          }
        } catch (_) {}
      }

      final order = OrderModel(
        id: '',
        orderNumber: orderNumber,
        userId: userId,
        workerId: null,
        items: itemsModel,
        addressSnapshot: {'address': effectiveAddress ?? ''},
        subtotal: event.request.totalAmount,
        discount: 0.0,
        tax: 0.0,
        total: event.request.totalAmount,
        orderStatus: OrderStatus.pending,
        paymentStatus: PaymentStatus.pending,
        scheduledAt: Timestamp.now(),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
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
          // Build order with payment status and create remote doc (preferred)
          final paidOrder = OrderModel(
            id: '',
            orderNumber: order.orderNumber,
            userId: order.userId,
            workerId: null,
            items: order.items,
            addressSnapshot: order.addressSnapshot,
            subtotal: order.subtotal,
            discount: order.discount,
            tax: order.tax,
            total: order.total,
            orderStatus: OrderStatus.pending,
            paymentStatus: PaymentStatus.paid,
            scheduledAt: order.scheduledAt,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );
          OrderModel savedRemote;
          try {
            savedRemote = await _orderRepo.createOrder(paidOrder, userId: userId);
          } catch (e) {
            debugPrint('[CheckoutBloc] createOrder(userId:$userId) failed after Razorpay: $e');
            // Fallback: try uploadOrder
            try {
              final remoteId = await _orderRepo.uploadOrder(order: paidOrder);
              // read back saved remote
              savedRemote = (await _orderRepo.getAllOrdersForUser(userId)).firstWhere((o) => o.id == remoteId, orElse: () => paidOrder);
            } catch (_) {
              savedRemote = paidOrder;
            }
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
            savedRemote = await _orderRepo.createOrder(order, userId: userId);
          } catch (e) {
            debugPrint('[CheckoutBloc] createOrder(userId:$userId) failed (COD): $e');
            // fallback to uploadOrder
            try {
              final rid = await _orderRepo.uploadOrder(order: order);
              savedRemote = (await _orderRepo.getAllOrdersForUser(userId)).firstWhere((o) => o.id == rid, orElse: () => order);
            } catch (_) {
              savedRemote = order;
            }
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
