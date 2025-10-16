import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../../core/models/order_model.dart';
import '../../../../../core/services/session_service.dart';
import 'order_event.dart';
import 'order_state.dart';
import '../data/repositories/order_repository.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;

  OrderBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(OrderLoading()) {
    on<LoadOrders>(_onLoadOrders);
    on<AddOrder>(_onAddOrder);
  }

  // Make handlers explicitly async for clarity
  Future<void> _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) async {
    try {
      final orders = await _orderRepository.fetchOrdersForUser(event.userId);
      emit(OrderLoaded(orders));
    } catch (e) {
      // Surface error message so UI can display it (e.g., permission-denied from Firestore)
      final message = e is FirebaseException ? (e.message ?? e.toString()) : e.toString();
      emit(OrderError(message));
    }
  }

  /// Adds an order. This method is resilient:
  /// - If orders are already loaded we update them in memory (optimistic UI).
  /// - If orders are not loaded we attempt to fetch existing orders first.
  /// - We try to resolve a missing addressSnapshot from session or Firestore before persisting.
  /// - Persistence failures don't crash the app; we keep optimistic UI and try to reconcile by refetching.
  Future<void> _onAddOrder(AddOrder event, Emitter<OrderState> emit) async {
    // Obtain a mutable list of current orders. If not loaded, try fetching from repository.
    List<OrderModel> currentOrders = [];
    if (state is OrderLoaded) {
      currentOrders = List.from((state as OrderLoaded).orders);
    } else {
      try {
        currentOrders = await _orderRepository.fetchOrdersForUser(event.order.userId);
      } catch (_) {
        // If fetch fails, start with an empty list (optimistic behavior)
        currentOrders = [];
      }
    }

    // Optimistically add the new order to UI state
    currentOrders.add(event.order);
    emit(OrderLoaded(currentOrders));

    // Resolve addressSnapshot before saving (if missing)
    OrderModel orderToSave = event.order;
    try {
      if (orderToSave.addressSnapshot.isEmpty) {
        orderToSave = await _resolveUserAddress(orderToSave);
      }
    } catch (_) {
      // ignore address resolution errors - proceed with what we have
    }

    // Try to persist the order. If it fails, keep optimistic UI and attempt a reconciliation fetch.
    try {
      await _orderRepository.createOrder(orderToSave, userId: orderToSave.userId);
    } catch (e) {
      // Persistence failed. Attempt to re-sync by refetching the authoritative list.
      try {
        final refreshed = await _orderRepository.fetchOrdersForUser(orderToSave.userId);
        emit(OrderLoaded(refreshed));
      } catch (_) {
        // If reconciliation also fails, keep optimistic list but do not crash.
        // Optionally, an app-level notification could be triggered here.
        emit(OrderLoaded(currentOrders));
      }
    }
  }

  /// Try to resolve a user's address from local session, then Firestore users/{uid}.
  /// Returns a new [OrderModel] with addressSnapshot set when found, otherwise returns the original order.
  Future<OrderModel> _resolveUserAddress(OrderModel order) async {
    String? resolvedAddress;

    // 1) SessionService
    try {
      final session = SessionService();
      final su = session.getUser();
      if (su != null && su.addresses != null && su.addresses!.isNotEmpty) {
        final dynamic first = su.addresses!.first;
        if (first is String) resolvedAddress = first;
        if (first is Map && first['address'] is String) resolvedAddress = first['address'] as String;
      }
    } catch (_) {
      // ignore and fallback to Firestore
    }

    // 2) Firestore users/{uid}
    if (resolvedAddress == null) {
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final uid = firebaseUser?.uid ?? order.userId;
        if (uid.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            final data = doc.data();
            if (data != null && data['addresses'] is List && (data['addresses'] as List).isNotEmpty) {
              final dynamic first = (data['addresses'] as List).first;
              if (first is String) resolvedAddress = first;
              if (first is Map && first['address'] is String) resolvedAddress = first['address'] as String;
            }
          }
        }
      } catch (_) {
        // ignore
      }
    }

    if (resolvedAddress == null) return order;

    // Build a minimal addressSnapshot map and return a new OrderModel with it
    final Map<String, dynamic> addressSnapshot = {'address': resolvedAddress};

    return OrderModel(
      id: order.id,
      orderNumber: order.orderNumber,
      userId: order.userId,
      workerId: order.workerId,
      items: order.items,
      addressSnapshot: addressSnapshot,
      subtotal: order.subtotal,
      discount: order.discount,
      tax: order.tax,
      total: order.total,
      orderStatus: order.orderStatus,
      paymentStatus: order.paymentStatus,
      scheduledAt: order.scheduledAt,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
    );
  }
}
