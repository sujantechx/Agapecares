// File: lib/shared/services/firestore_local_database_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/user_app/cart/data/models/cart_item_model.dart';
import '../models/order_model.dart';
import 'local_database_service.dart';

// Firestore-backed implementation of LocalDatabaseService.
// This class stores cart items and orders directly under /users/{userId}/cart and /users/{userId}/orders.
// If no authenticated user is available or Firestore operations fail, it falls back to an in-memory cache.
class FirestoreLocalDatabaseService implements LocalDatabaseService {
  final FirebaseFirestore _firestore;

  // In-memory fallbacks for unauthenticated or error cases
  final Map<int, OrderModel> _inMemoryOrders = {};
  int _nextInMemoryOrderId = 1;

  final Map<String, CartItemModel> _fallbackCart = {};

  FirestoreLocalDatabaseService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> init() async {
    // Nothing to initialize for Firestore; keep method for interface compatibility.
    return;
  }

  String _userIdOrEmpty() {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return '';
      return u.uid.trim();
    } catch (_) {
      return '';
    }
  }

  CollectionReference _userOrdersCol(String userId) => _firestore.collection('users').doc(userId).collection('orders');
  CollectionReference _userCartCol(String userId) => _firestore.collection('users').doc(userId).collection('cart');

  @override
  Future<OrderModel> createOrder(OrderModel order) async {
    // Prefer to create the order remotely in Firestore when called explicitly via OrderRepository.uploadOrder.
    // For local saves (used when uploadRemote=false), we must NOT create remote docs here as that
    // leads to duplicate remote orders. Instead, keep a reliable in-memory local store for unsynced orders.
    // This keeps Firestore writes centralized in OrderRepository.createOrder/uploadOrder.
    final id = _nextInMemoryOrderId++;
    final now = order.createdAt;
    // Construct a new OrderModel instance with localId and createdAt set. copyWith doesn't allow changing createdAt.
    final saved = OrderModel(
      localId: id,
      isSynced: false,
      id: order.id,
      orderNumber: order.orderNumber,
      paymentStatus: order.paymentStatus,
      userId: order.userId,
      items: order.items,
      subtotal: order.subtotal,
      discount: order.discount,
      total: order.total,
      paymentMethod: order.paymentMethod,
      paymentId: order.paymentId,
      orderStatus: order.orderStatus,
      userName: order.userName,
      userEmail: order.userEmail,
      userPhone: order.userPhone,
      userAddress: order.userAddress,
      workerId: order.workerId,
      workerName: order.workerName,
      acceptedAt: order.acceptedAt,
      rating: order.rating,
      review: order.review,
      createdAt: now,
    );
    _inMemoryOrders[id] = saved;
    return saved;
  }

  @override
  Future<List<OrderModel>> getUnsyncedOrders() async {
    // We're operating Firestore-first; treat in-memory orders as unsynced fallback.
    return _inMemoryOrders.values.where((o) => !o.isSynced).toList();
  }

  @override
  Future<void> markOrderAsSynced(int localId) async {
    // Remove from in-memory unsynced map if present. If Firestore is primary, there's nothing else to do.
    if (_inMemoryOrders.containsKey(localId)) {
      final existing = _inMemoryOrders[localId]!;
      _inMemoryOrders[localId] = existing.copyWith(isSynced: true);
    }
  }

  @override
  Future<void> close() async {
    // No persistent local DB to close.
    return;
  }

  @override
  Future<void> updateOrder(OrderModel order) async {
    // Update remote document if remote id present; otherwise update in-memory copy when available.
    try {
      if (order.id != null && order.id!.trim().isNotEmpty) {
        final userId = order.userId.trim().isNotEmpty ? order.userId : _userIdOrEmpty();
        if (userId.isNotEmpty) {
          final doc = _userOrdersCol(userId).doc(order.id);
          await doc.set(order.toFirebaseJson(), SetOptions(merge: true));
          return;
        }
      }
    } catch (_) {}

    // Fallback: update in-memory
    if (order.localId != null) {
      _inMemoryOrders[order.localId!] = order;
    }
  }

  @override
  Future<void> markOrderAsFailed(int localId, {String? failureReason}) async {
    // Update in-memory or remote if we can map localId to a remote doc (not tracked here). Keep simple: update in-memory.
    final existing = _inMemoryOrders[localId];
    if (existing != null) {
      _inMemoryOrders[localId] = existing.copyWith(orderStatus: 'failed');
    }
  }

  // --- Cart related methods (firestore-backed) ---
  @override
  Future<List<CartItemModel>> getCartItems() async {
    try {
      final uid = _userIdOrEmpty();
      if (uid.isEmpty) return _fallbackCart.values.toList();
      final snap = await _userCartCol(uid).get();
      return snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return CartItemModel.fromJson(Map<String, dynamic>.from(data));
      }).toList();
    } catch (e) {
      return _fallbackCart.values.toList();
    }
  }

  @override
  Future<void> addCartItem(CartItemModel item) async {
    try {
      final uid = _userIdOrEmpty();
      if (uid.isEmpty) {
        // fallback in-memory
        final existing = _fallbackCart[item.id];
        if (existing != null) _fallbackCart[item.id] = existing.copyWith(quantity: existing.quantity + item.quantity);
        else _fallbackCart[item.id] = item;
        return;
      }
      final doc = _userCartCol(uid).doc(item.id);
      await doc.set(item.toJson());
    } catch (e) {
      // best-effort fallback
      final existing = _fallbackCart[item.id];
      if (existing != null) _fallbackCart[item.id] = existing.copyWith(quantity: existing.quantity + item.quantity);
      else _fallbackCart[item.id] = item;
    }
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    try {
      final uid = _userIdOrEmpty();
      if (uid.isEmpty) {
        _fallbackCart.remove(cartItemId);
        return;
      }
      await _userCartCol(uid).doc(cartItemId).delete();
    } catch (e) {
      _fallbackCart.remove(cartItemId);
    }
  }

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int newQuantity) async {
    try {
      final uid = _userIdOrEmpty();
      if (uid.isEmpty) {
        final existing = _fallbackCart[cartItemId];
        if (existing == null) return;
        if (newQuantity > 0) _fallbackCart[cartItemId] = existing.copyWith(quantity: newQuantity);
        else _fallbackCart.remove(cartItemId);
        return;
      }
      final docRef = _userCartCol(uid).doc(cartItemId);
      if (newQuantity > 0) await docRef.update({'quantity': newQuantity});
      else await docRef.delete();
    } catch (e) {
      final existing = _fallbackCart[cartItemId];
      if (existing == null) return;
      if (newQuantity > 0) _fallbackCart[cartItemId] = existing.copyWith(quantity: newQuantity);
      else _fallbackCart.remove(cartItemId);
    }
  }

  @override
  Future<void> clearCart() async {
    try {
      final uid = _userIdOrEmpty();
      if (uid.isEmpty) {
        _fallbackCart.clear();
        return;
      }
      final col = _userCartCol(uid);
      final snap = await col.get();
      for (final d in snap.docs) {
        try {
          await d.reference.delete();
        } catch (_) {}
      }
    } catch (e) {
      _fallbackCart.clear();
    }
  }
}
