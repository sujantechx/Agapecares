import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agapecares/core/models/cart_item_model.dart';

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
  String _docIdForParts(String serviceId, String optionName) => '${serviceId}_${optionName}';

  @override
  Future<void> addItemToCart(CartItemModel item) async {
    final userId = _getCurrentUserId();
    if (userId == null) return; // not authenticated, skip remote write
    final docId = _docIdForItem(item);
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(docId)
          .set(item.toMap());
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
      await batch.commit();
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<List<CartItemModel>> getCartItems() async {
    final uid = _getCurrentUserId();
    if (uid == null) return [];
    final snapshot =
        await _firestore.collection('users').doc(uid).collection('cart').get();
    return snapshot.docs
        .map((doc) => CartItemModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> removeItemFromCart(String cartItemId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartItemId)
          .delete();
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<void> updateItemQuantity(String cartItemId, int quantity) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartItemId)
          .update({'quantity': quantity});
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
      await _firestore.collection('users').doc(userId).collection('cart').doc(docId).set(item.toMap());
    } on FirebaseException {
      rethrow;
    }
  }

  @override
  Future<void> removeCartItem(String userId, String itemId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('cart').doc(itemId).delete();
    } on FirebaseException {
      rethrow;
    }
  }
}