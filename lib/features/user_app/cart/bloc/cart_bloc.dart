import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../shared/models/offer_model.dart';
import '../../data/repositories/offer_repository.dart';
import '../data/models/cart_item_model.dart';

import '../data/repository/cart_repository.dart';

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

  // ... (onCartItemAdded, onCartItemRemoved, etc. are the same)
  // They just need to call the new _recalculateState method at the end.

  Future<void> _onCartCouponApplied(CartCouponApplied event, Emitter<CartState> emit) async {
    final offer = await _offerRepository.getOfferByCode(event.couponCode);
    await _recalculateState(emit, appliedCoupon: offer, couponError: offer == null ? "Invalid Coupon Code" : null);
  }

  // 🎯 A new, powerful helper to calculate everything
  Future<void> _recalculateState(Emitter<CartState> emit, {Offer? appliedCoupon, String? couponError}) async {
    final items = await _cartRepository.getCartItems();
    if (items.isEmpty) {
      return emit(const CartState()); // Reset if cart is empty
    }

    // Determine which coupon to use (the new one or the one already in the state)
    final couponToApply = appliedCoupon ?? state.appliedCoupon;

    // Calculation starts
    final subtotal = items.fold(0.0, (sum, item) => sum + item.price);
    double couponDiscount = 0.0;

    // 1. Apply Coupon Discount (Flat or Percentage)
    if (couponToApply != null && (couponToApply.minimumSpend == null || subtotal >= couponToApply.minimumSpend!)) {
      if (couponToApply.type == OfferType.percentage) {
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
      // This example is percentage, but could be flat too
      extraDiscount = priceAfterCoupon * (extraOffer.value / 100);
    }

    // 3. Calculate Final Total
    final total = priceAfterCoupon - extraDiscount;

    // Emit the final, detailed state
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

  // --- All previous event handlers now just call _recalculateState ---

  Future<void> _onCartStarted(CartStarted event, Emitter<CartState> emit) async {
    await _recalculateState(emit);
  }

  Future<void> _onCartItemAdded(CartItemAdded event, Emitter<CartState> emit) async {
    await _cartRepository.addItemToCart(event.item);
    await _recalculateState(emit);
  }

  Future<void> _onCartItemRemoved(CartItemRemoved event, Emitter<CartState> emit) async {
    await _cartRepository.removeItemFromCart(event.cartItemId);
    await _recalculateState(emit);
  }

  // (Implement the same for Increased/Decreased quantity handlers)
  Future<void> _onCartItemQuantityIncreased(CartItemQuantityIncreased event, Emitter<CartState> emit) async {
    final item = state.items.firstWhere((i) => i.id == event.cartItemId);
    await _cartRepository.updateItemQuantity(event.cartItemId, item.quantity + 1);
    await _recalculateState(emit);
  }

  Future<void> _onCartItemQuantityDecreased(CartItemQuantityDecreased event, Emitter<CartState> emit) async {
    final item = state.items.firstWhere((i) => i.id == event.cartItemId);
    await _cartRepository.updateItemQuantity(event.cartItemId, item.quantity - 1);
    await _recalculateState(emit);
  }
}