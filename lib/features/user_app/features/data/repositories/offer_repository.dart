import 'package:agapecares/core/models/coupon_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferRepository {
  // A dummy list of available coupons in our system represented by CouponModel
  static final List<CouponModel> _availableCoupons = [
    CouponModel(
      id: 'AGAPE10',
      description: 'Get 10% off your total order.',
      type: CouponType.percentage,
      value: 10.0,
      minOrderValue: 500.0,
      usedCount: 0,
      expiryDate: Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
      // expiryDate will be set here correctly
    ),
    CouponModel(
      id: 'FLAT150',
      description: 'Get a flat ₹150 off.',
      type: CouponType.fixedAmount,
      value: 150.0,
      minOrderValue: 1000.0,
      usedCount: 0,
      expiryDate: Timestamp.now(),
    ),
  ];

  // Finds a coupon by its code
  Future<CouponModel?> getOfferByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate latency
    try {
      return _availableCoupons.firstWhere((c) => c.id.toUpperCase() == code.toUpperCase());
    } catch (e) {
      return null;
    }
  }

  // Gets an automatic "extra" coupon based on the current total
  CouponModel? getExtraOffer(double currentTotal) {
    if (currentTotal >= 2000) {
      return CouponModel(
        id: 'EXTRA5',
        description: 'Extra 5% off for orders above ₹2000!',
        type: CouponType.percentage,
        value: 5.0,
        minOrderValue: 2000.0,
        usedCount: 0,
        expiryDate: Timestamp.now(),
      );
    }
    return null;
  }
}