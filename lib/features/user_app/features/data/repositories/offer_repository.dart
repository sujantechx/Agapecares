import 'package:agapecares/core/models/coupon_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferRepository {
  final FirebaseFirestore _firestore;

  OfferRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // A small in-memory fallback list for environments where Firestore is not reachable.
  static final List<CouponModel> _fallbackCoupons = [
    CouponModel(
      id: 'AGAPE10',
      description: 'Get 10% off your total order.',
      type: CouponType.percentage,
      value: 10.0,
      minOrderValue: 500.0,
      usedCount: 0,
      expiryDate: Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
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

  CollectionReference<Map<String, dynamic>> get _couponCol => _firestore.collection('coupons');

  // Fetches coupons from Firestore. Falls back to the in-memory list if Firestore query fails.
  Future<List<CouponModel>> listCoupons() async {
    try {
      final snap = await _couponCol.get();
      return snap.docs.map((d) => CouponModel.fromFirestore(d)).toList();
    } catch (e) {
      // Fallback
      return Future.value(List<CouponModel>.from(_fallbackCoupons));
    }
  }

  // Adds or overwrites a coupon (doc id = coupon.id)
  Future<void> addOrUpdateCoupon(CouponModel coupon) async {
    final data = coupon.toFirestore();
    try {
      await _couponCol.doc(coupon.id).set(data);
    } catch (e) {
      // If Firestore is unavailable, update the fallback list
      final idx = _fallbackCoupons.indexWhere((c) => c.id == coupon.id);
      if (idx >= 0) _fallbackCoupons[idx] = coupon;
      else _fallbackCoupons.add(coupon);
    }
  }

  Future<void> deleteCoupon(String id) async {
    try {
      await _couponCol.doc(id).delete();
    } catch (e) {
      _fallbackCoupons.removeWhere((c) => c.id == id);
    }
  }

  // Finds a coupon by its code, first trying Firestore and falling back to the in-memory list.
  Future<CouponModel?> getOfferByCode(String code) async {
    try {
      final doc = await _couponCol.doc(code.toUpperCase()).get();
      if (doc.exists) return CouponModel.fromFirestore(doc);
    } catch (_) {}

    try {
      return _fallbackCoupons.firstWhere((c) => c.id.toUpperCase() == code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  // Gets an automatic "extra" coupon based on the current total. This is still kept
  // as an in-memory rule rather than stored in Firestore.
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