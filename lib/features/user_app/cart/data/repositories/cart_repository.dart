import '../../../../../core/models/cart_item_model.dart';


abstract class CartRepository {
  Future<List<CartItemModel>> getCartItems(String userId);
  Future<void> addCartItem(String userId, CartItemModel item);
  Future<void> removeCartItem(String userId, String cartItemId);
  Future<void> clearCart(String userId);
  Future<void> syncCartFromRemote();
}

