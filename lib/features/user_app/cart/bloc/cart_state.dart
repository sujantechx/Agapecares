
import 'package:equatable/equatable.dart';

import '../../../../shared/models/offer_model.dart';
import '../data/models/cart_item_model.dart';

class CartState extends Equatable {
  final List<CartItem> items;
  final double subtotal;
  final Offer? appliedCoupon;
  final double couponDiscount;
  final Offer? extraOffer;
  final double extraDiscount;
  final double total;
  final String? error; // To show messages like "Invalid Coupon"

  const CartState({
    this.items = const [],
    this.subtotal = 0.0,
    this.appliedCoupon,
    this.couponDiscount = 0.0,
    this.extraOffer,
    this.extraDiscount = 0.0,
    this.total = 0.0,
    this.error,
  });

  @override
  List<Object?> get props => [
    items,
    subtotal,
    appliedCoupon,
    couponDiscount,
    extraOffer,
    extraDiscount,
    total,
    error
  ];
}