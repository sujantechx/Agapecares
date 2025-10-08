import '../models/cart_item_model.dart';

class CartRepository {
  final List<CartItem> _cartItems = [];

  // Fetch all items from the cart
  Future<List<CartItem>> getCartItems() async {
    // In a real app, you might fetch this from a database or SharedPreferences.
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    return List.from(_cartItems);
  }

  // Add an item to the cart. If it already exists, increment the quantity.
  Future<void> addItemToCart(CartItem item) async {
    final existingItemIndex = _cartItems.indexWhere((i) => i.id == item.id);

    if (existingItemIndex != -1) {
      // Item already exists, so we update its quantity.
      final existingItem = _cartItems[existingItemIndex];
      _cartItems[existingItemIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );
    } else {
      // Item does not exist, add it to the cart.
      _cartItems.add(item);
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Remove an item from the cart completely.
  Future<void> removeItemFromCart(String cartItemId) async {
    _cartItems.removeWhere((item) => item.id == cartItemId);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // Update the quantity of a specific cart item.
  Future<void> updateItemQuantity(String cartItemId, int newQuantity) async {
    final itemIndex = _cartItems.indexWhere((i) => i.id == cartItemId);
    if (itemIndex != -1) {
      if (newQuantity > 0) {
        _cartItems[itemIndex] = _cartItems[itemIndex].copyWith(quantity: newQuantity);
      } else {
        // If quantity is 0 or less, remove the item.
        removeItemFromCart(cartItemId);
      }
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
}