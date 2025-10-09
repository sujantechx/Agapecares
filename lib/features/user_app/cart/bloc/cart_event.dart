
import '../data/models/cart_item_model.dart';
import 'package:equatable/equatable.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object> get props => [];
}

// Event to load the cart for the first time.
class CartStarted extends CartEvent {}

// Event to add an item.
class CartItemAdded extends CartEvent {
  final CartItemModel item;
  const CartItemAdded(this.item);
  @override
  List<Object> get props => [item];
}

// Event to remove an item.
class CartItemRemoved extends CartEvent {
  final String cartItemId;
  const CartItemRemoved(this.cartItemId);
  @override
  List<Object> get props => [cartItemId];
}

// Event to increment quantity.
class CartItemQuantityIncreased extends CartEvent {
  final String cartItemId;
  const CartItemQuantityIncreased(this.cartItemId);
  @override
  List<Object> get props => [cartItemId];
}

// Event to decrement quantity.
class CartItemQuantityDecreased extends CartEvent {
  final String cartItemId;
  const CartItemQuantityDecreased(this.cartItemId);
  @override
  List<Object> get props => [cartItemId];
}

// Event to apply a coupon.
class CartCouponApplied extends CartEvent {
  final String couponCode;
  const CartCouponApplied(this.couponCode);
  @override
  List<Object> get props => [couponCode];
}