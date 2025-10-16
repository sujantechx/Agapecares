import 'package:bloc/bloc.dart';
import 'package:agapecares/core/models/coupon_model.dart';
import 'package:agapecares/features/user_app/features/data/repositories/offer_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:agapecares/features/user_app/features/cart/data/repositories/cart_repository.dart';

import 'cart_event.dart';
import 'cart_state.dart'; // Import Offer repository



class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository _cartRepository;
  final OfferRepository _offerRepository; // 🎯 Inject OfferRepository

  CartBloc({
    required CartRepository cartRepository,
    required OfferRepository offerRepository,
  })  : _cartRepository = cartRepository,
        _offerRepository = offerRepository, // 🎯 Initialize it
        super(const CartState()) {
    on<CartStarted>(_onCartStarted);
    on<CartItemAdded>(_onCartItemAdded);
    on<CartItemRemoved>(_onCartItemRemoved);
    on<CartItemQuantityIncreased>(_onCartItemQuantityIncreased);
    on<CartItemQuantityDecreased>(_onCartItemQuantityDecreased);
    on<CartCouponApplied>(_onCartCouponApplied);
  }

  Future<void> _onCartCouponApplied(CartCouponApplied event, Emitter<CartState> emit) async {
    if (kDebugMode) debugPrint('CART_DEBUG: Applying coupon "${event.couponCode}" (start_console)');
    final coupon = await _offerRepository.getOfferByCode(event.couponCode);
    await _recalculateState(emit, appliedCoupon: coupon, couponError: coupon == null ? "Invalid Coupon Code" : null);
    if (kDebugMode) debugPrint('CART_DEBUG: Coupon applied (finished)');
  }

  // A helper to calculate totals using canonical CartItemModel fields
  Future<void> _recalculateState(Emitter<CartState> emit, {CouponModel? appliedCoupon, String? couponError}) async {
    if (kDebugMode) debugPrint('CART_DEBUG: Recalculating cart state (start_console)');
    final items = await _cartRepository.getCartItems();
    if (items.isEmpty) {
      if (kDebugMode) debugPrint('CART_DEBUG: Cart is empty after recalculation');
      return emit(const CartState(items: [])); // Reset if cart is empty
    }

    final couponToApply = appliedCoupon ?? state.appliedCoupon;

    // subtotal = sum(unitPrice * quantity)
    final subtotal = items.fold<double>(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
    double couponDiscount = 0.0;

    // 1. Apply Coupon Discount
    if (couponToApply != null && (couponToApply.minOrderValue == null || subtotal >= couponToApply.minOrderValue!)) {
      if (couponToApply.type == CouponType.percentage) {
        couponDiscount = subtotal * (couponToApply.value / 100);
      } else {
        couponDiscount = couponToApply.value;
      }
    }

    final priceAfterCoupon = subtotal - couponDiscount;

    // 2. Apply Extra Automatic Discount
    final extraOffer = _offerRepository.getExtraOffer(priceAfterCoupon);
    double extraDiscount = 0.0;
    if (extraOffer != null) {
      extraDiscount = priceAfterCoupon * (extraOffer.value / 100);
    }

    final total = priceAfterCoupon - extraDiscount;

    if (kDebugMode) debugPrint('CART_DEBUG: Recalculated totals subtotal=$subtotal couponDiscount=$couponDiscount extraDiscount=$extraDiscount total=$total');

    emit(CartState(
      items: items,
      subtotal: subtotal,
      appliedCoupon: couponToApply,
      couponDiscount: couponDiscount,
      extraOffer: extraOffer,
      extraDiscount: extraDiscount,
      total: total,
      error: couponError,
    ));
  }

  Future<void> _onCartStarted(CartStarted event, Emitter<CartState> emit) async {
    if (kDebugMode) debugPrint('CART_DEBUG: CartStarted received (start_console)');
    await _recalculateState(emit);
    if (kDebugMode) debugPrint('CART_DEBUG: CartStarted processed (finished)');
  }

  Future<void> _onCartItemAdded(CartItemAdded event, Emitter<CartState> emit) async {
    // The CartRepository expects a CartItemModel; ensure caller provides that.
    if (kDebugMode) debugPrint('CART_DEBUG: Adding item to cart: ${event.item.serviceName} | option=${event.item.optionName} (start_console)');
    await _cartRepository.addItemToCart(event.item);
    if (kDebugMode) debugPrint('CART_DEBUG: addItemToCart call returned, recalculating state');
    await _recalculateState(emit);
    if (kDebugMode) debugPrint('CART_DEBUG: Item added and state updated (finished)');
  }

  Future<void> _onCartItemRemoved(CartItemRemoved event, Emitter<CartState> emit) async {
    if (kDebugMode) debugPrint('CART_DEBUG: Removing cart item id=${event.cartItemId} (start_console)');
    await _cartRepository.removeItemFromCart(event.cartItemId);
    await _recalculateState(emit);
    if (kDebugMode) debugPrint('CART_DEBUG: Item removed and state updated (finished)');
  }

  Future<void> _onCartItemQuantityIncreased(CartItemQuantityIncreased event, Emitter<CartState> emit) async {
    if (kDebugMode) debugPrint('CART_DEBUG: Increasing quantity for ${event.cartItemId} (start_console)');
    final item = state.items.firstWhere((i) => (i.serviceId + '_' + i.optionName) == event.cartItemId);
    await _cartRepository.updateItemQuantity(event.cartItemId, item.quantity + 1);
    await _recalculateState(emit);
    if (kDebugMode) debugPrint('CART_DEBUG: Quantity increased (finished)');
  }

  Future<void> _onCartItemQuantityDecreased(CartItemQuantityDecreased event, Emitter<CartState> emit) async {
    if (kDebugMode) debugPrint('CART_DEBUG: Decreasing quantity for ${event.cartItemId} (start_console)');
    final item = state.items.firstWhere((i) => (i.serviceId + '_' + i.optionName) == event.cartItemId);
    await _cartRepository.updateItemQuantity(event.cartItemId, item.quantity - 1);
    await _recalculateState(emit);
    if (kDebugMode) debugPrint('CART_DEBUG: Quantity decreased (finished)');
  }
}