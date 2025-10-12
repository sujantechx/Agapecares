import 'dart:convert';
import 'package:agapecares/shared/services/local_database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import 'package:agapecares/shared/services/session_service.dart';

// Top-level function used by compute to parse a remote cart items list into a List<Map<String, dynamic>>.
// This runs in a background isolate to avoid JSON decoding on the UI thread.
List<Map<String, dynamic>> _parseCartItemsForCompute(dynamic itemsJson) {
  final List<Map<String, dynamic>> parsed = [];
  try {
    if (itemsJson is List) {
      for (final e in itemsJson) {
        try {
          if (e is Map) {
            parsed.add(Map<String, dynamic>.from(e));
          } else if (e is String && e.isNotEmpty) {
            final dyn = jsonDecode(e);
            if (dyn is Map) parsed.add(Map<String, dynamic>.from(dyn));
          }
        } catch (_) {
          // skip bad entries
        }
      }
    }
  } catch (_) {}
  return parsed;
}

/// CartRepository now persists cart items using LocalDatabaseService (SQLite/Web-memory)
/// and optionally syncs with Firestore when a user is authenticated (phone number as id).
class CartRepository {
  final LocalDatabaseService _localDb;
  final FirebaseFirestore _firestore;
  final SessionService? _sessionService;

  CartRepository({required LocalDatabaseService localDb, FirebaseFirestore? firestore, SessionService? sessionService})
      : _localDb = localDb,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionService = sessionService;

  // Helper to obtain a stable user id: prefer FirebaseAuth currentUser, then SessionService user
  String? _getCurrentUserId() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final phone = firebaseUser.phoneNumber?.trim();
      if (phone != null && phone.isNotEmpty) return phone;
      final uid = firebaseUser.uid.trim();
      if (uid.isNotEmpty) return uid;
    }

    try {
      final sessionUser = _sessionService?.getUser();
      if (sessionUser != null) {
        final phone = sessionUser.phoneNumber?.trim();
        if (phone != null && phone.isNotEmpty) return phone;
        final sid = sessionUser.uid.trim();
        if (sid.isNotEmpty) return sid;
      }
    } catch (_) {}

    return null;
  }

  // Fetch all items from the cart. If local DB is empty, attempt to load remote cart
  // for authenticated user and seed the local DB.
  Future<List<CartItemModel>> getCartItems() async {
    debugPrint('[CartRepository] getCartItems -> reading local DB');
    final local = await _localDb.getCartItems();
    debugPrint('[CartRepository] local count=${local.length}');
    if (local.isNotEmpty) return local;

    // Try to load remote cart if user is logged in
    try {
      final userId = _getCurrentUserId();
      debugPrint('[CartRepository] currentUser userId=$userId');
      if (userId == null || userId.isEmpty) {
        debugPrint('[CartRepository] no valid userId, skipping remote cart load');
        return [];
      }
      final doc = await _firestore.collection('carts').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final itemsJson = data?['items'] as List<dynamic>?;
        if (itemsJson != null && itemsJson.isNotEmpty) {
          // Parse items in background isolate to avoid jank
          final parsed = await compute(_parseCartItemsForCompute, itemsJson);
          final items = parsed.map((e) => CartItemModel.fromJson(e)).toList();
          // Seed local DB
          for (final it in items) {
            await _localDb.addCartItem(it);
          }
          debugPrint('[CartRepository] seeded local DB with ${items.length} items from remote');
          return items;
        }
      }
    } catch (e, s) {
      debugPrint('[CartRepository] remote load failed: $e\n$s');
      // ignore remote errors and fall back to local empty cart
    }

    return [];
  }

  // Add an item to the cart. If it already exists, increment the quantity.
  Future<void> addItemToCart(CartItemModel item) async {
    debugPrint('[CartRepository] addItemToCart id=${item.id} qty=${item.quantity}');
    await _localDb.addCartItem(item);
    debugPrint('[CartRepository] local add completed, syncing remote if needed');
    await _syncCartToRemoteIfAuthenticated();
  }

  // Remove an item from the cart completely.
  Future<void> removeItemFromCart(String cartItemId) async {
    debugPrint('[CartRepository] removeItemFromCart id=$cartItemId');
    await _localDb.removeCartItem(cartItemId);
    await _syncCartToRemoteIfAuthenticated();
  }

  // Update the quantity of a specific cart item.
  Future<void> updateItemQuantity(String cartItemId, int newQuantity) async {
    debugPrint('[CartRepository] updateItemQuantity id=$cartItemId newQty=$newQuantity');
    await _localDb.updateCartItemQuantity(cartItemId, newQuantity);
    await _syncCartToRemoteIfAuthenticated();
  }

  // Clear cart
  Future<void> clearCart() async {
    debugPrint('[CartRepository] clearCart');
    await _localDb.clearCart();
    await _syncCartToRemoteIfAuthenticated();
  }

  Future<void> _syncCartToRemoteIfAuthenticated() async {
    try {
      final userId = _getCurrentUserId();
      debugPrint('[CartRepository] _syncCartToRemoteIfAuthenticated userId=$userId');
      if (userId == null || userId.isEmpty) return;
      final items = await _localDb.getCartItems();
      final jsonItems = items.map((i) => i.toJson()).toList();
      await _firestore.collection('carts').doc(userId).set({'items': jsonItems});
      debugPrint('[CartRepository] remote sync completed items=${jsonItems.length}');
    } catch (e, s) {
      debugPrint('[CartRepository] remote sync failed: $e\n$s');
      // if remote sync fails, ignore; SyncService / retry can be implemented later
    }
  }
}