// File: lib/shared/services/local_database_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/user_app/features/cart/data/models/cart_item_model.dart';
import '../models/order_model.dart';


/// LocalDatabaseService defines the minimal contract used by repositories
/// to save orders and cart items. The app uses a Firestore-backed
/// implementation (`FirestoreLocalDatabaseService`) by default; this file
/// contains only the interface and a tiny in-memory fallback for tests.
abstract class LocalDatabaseService {
  Future<void> init();
  Future<OrderModel> createOrder(OrderModel order);
  Future<List<OrderModel>> getUnsyncedOrders();
  Future<void> markOrderAsSynced(int localId);
  Future<void> close();

  Future<void> updateOrder(OrderModel order);
  Future<void> markOrderAsFailed(int localId, {String? failureReason});

  // Cart related methods
  Future<List<CartItemModel>> getCartItems();
  Future<void> addCartItem(CartItemModel item);
  Future<void> removeCartItem(String cartItemId);
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity);
  Future<void> clearCart();
}

/// Simple in-memory fallback local DB used when no persistent store is available.
/// This is intentionally small and only used for tests or when Firestore isn't
/// available; production apps should use the Firestore implementation.
class InMemoryLocalDatabaseService implements LocalDatabaseService {
  final Map<int, OrderModel> _orders = {};
  int _nextOrderId = 1;
  final Map<String, CartItemModel> _cart = {};

  @override
  Future<void> init() async {}

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    final id = _nextOrderId++;
    final saved = order.copyWith(localId: id);
    _orders[id] = saved;
    return saved;
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async => _orders.values.where((o) => !o.isSynced).toList();

  @override
  Future<void> markOrderAsSynced(int localId) async {
    final existing = _orders[localId];
    if (existing != null) _orders[localId] = existing.copyWith(isSynced: true);
  }

  @override
  Future<void> close() async {
    _orders.clear();
    _cart.clear();
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    if (order.localId == null) return;
    _orders[order.localId!] = order;
  }

  @override
  Future<void> markOrderAsFailed(int localId, {String? failureReason}) async {
    final existing = _orders[localId];
    if (existing != null) _orders[localId] = existing.copyWith(orderStatus: 'failed');
  }

  @override
  Future<List<CartItemModel>> getCartItems() async => _cart.values.toList();

  @override
  Future<void> addCartItem(CartItemModel item) async {
    final existing = _cart[item.id];
    if (existing != null) _cart[item.id] = existing.copyWith(quantity: existing.quantity + item.quantity);
    else _cart[item.id] = item;
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    _cart.remove(cartItemId);
  }

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {
    final existing = _cart[cartItemId];
    if (existing == null) return;
    if (newQuantity > 0) _cart[cartItemId] = existing.copyWith(quantity: newQuantity);
    else _cart.remove(cartItemId);
  }

  @override
  Future<void> clearCart() async {
    _cart.clear();
  }
}

// Top-level function used by compute to decode JSON in a background isolate.
dynamic _backgroundDecode(String raw) {
  return jsonDecode(raw);
}
