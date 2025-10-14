import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../shared/models/cart_item_model.dart';
import 'cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  final FirebaseFirestore _firestore;

  CartRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> addCartItem(String userId, CartItemModel item) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(item.id)
        .set(item.toFirestore());
  }

  @override
  Future<void> clearCart(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).collection('cart').get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<List<CartItemModel>> getCartItems(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).collection('cart').get();
    return snapshot.docs
        .map((doc) => CartItemModel.fromFirestore(doc.data() as DocumentSnapshot<Map<String, dynamic>>, doc.id))
        .toList();
  }

  @override
  Future<void> removeCartItem(String userId, String cartItemId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(cartItemId)
        .delete();
  }

  @override
  Future<void> syncCartFromRemote() {
    // TODO: implement syncCartFromRemote
    throw UnimplementedError();
  }
}

