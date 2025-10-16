import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agapecares/core/models/cart_item_model.dart';
import 'package:flutter/foundation.dart';

import 'cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CartRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? _getCurrentUserId() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      final phone = firebaseUser.phoneNumber?.trim();
      if (phone != null && phone.isNotEmpty) return phone;
      final uid = firebaseUser.uid.trim();
      if (uid.isNotEmpty) return uid;
    }
    return null;
  }

  String _docIdForItem(CartItemModel item) => '${item.serviceId}_${item.optionName}';

  @override
  Future<void> addItemToCart(CartItemModel item) async {
    final userId = _getCurrentUserId();
    if (userId == null) return; // not authenticated, skip remote write
    final docId = _docIdForItem(item);
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.addItemToCart start_console user=$userId doc=$docId');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(docId)
          .set(item.toMap());
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.addItemToCart finished user=$userId doc=$docId');
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<void> clearCart() async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    final snapshot =
        await _firestore.collection('users').doc(userId).collection('cart').get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.clearCart start_console user=$userId');
      await batch.commit();
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.clearCart finished user=$userId');
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<List<CartItemModel>> getCartItems() async {
    final uid = _getCurrentUserId();
    if (uid == null) return [];
    if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.getCartItems start_console user=$uid');
    final snapshot =
        await _firestore.collection('users').doc(uid).collection('cart').get();
    // QueryDocumentSnapshot.data() returns Map<String, dynamic> for Firestore
    final items = snapshot.docs.map((doc) => CartItemModel.fromMap(doc.data())).toList();
    if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.getCartItems finished user=$uid count=${items.length}');
    return items;
  }

  @override
  Future<void> removeItemFromCart(String cartItemId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.removeItemFromCart start_console user=$userId id=$cartItemId');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartItemId)
          .delete();
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.removeItemFromCart finished user=$userId id=$cartItemId');
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<void> updateItemQuantity(String cartItemId, int quantity) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.updateItemQuantity start_console user=$userId id=$cartItemId qty=$quantity');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartItemId)
          .update({'quantity': quantity});
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.updateItemQuantity finished user=$userId id=$cartItemId qty=$quantity');
    } on FirebaseException {
      rethrow;
    }
  }

  // Keep original name for compatibility; implement as a convenience method.
  Future<void> syncCartFromRemote() async {
    // No-op placeholder; sync is handled elsewhere in the app.
    return;
  }

  @override
  Future<void> addCartItem(String userId, CartItemModel item) async {
    final docId = _docIdForItem(item);
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.addCartItem start_console user=$userId doc=$docId');
      await _firestore.collection('users').doc(userId).collection('cart').doc(docId).set(item.toMap());
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.addCartItem finished user=$userId doc=$docId');
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<void> removeCartItem(String userId, String itemId) async {
    try {
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.removeCartItem start_console user=$userId id=$itemId');
      await _firestore.collection('users').doc(userId).collection('cart').doc(itemId).delete();
      if (kDebugMode) debugPrint('CART_DEBUG: CartRepository.removeCartItem finished user=$userId id=$itemId');
    } on FirebaseException {
      rethrow;
    }
  }
}