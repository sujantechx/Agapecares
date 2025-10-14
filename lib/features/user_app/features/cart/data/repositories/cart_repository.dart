import 'package:agapecares/core/models/cart_item_model.dart';

/// CartRepository interface used across the app.
/// Keep method names compatible with existing concrete implementations.
abstract class CartRepository {
  Future<List<CartItemModel>> getCartItems(userId);
  Future<void> addItemToCart(CartItemModel item);
  Future<void> removeItemFromCart(String cartItemId);
  Future<void> updateItemQuantity(String cartItemId, int quantity);
  Future<void> clearCart();

  Future<void> addCartItem(String userId, CartItemModel item) async {}

  Future<void> removeCartItem(String userId, String itemId) async {}
}
