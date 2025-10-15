// lib/models/coupon_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum for the type of discount a coupon provides.
enum CouponType { percentage, fixedAmount }

/// Represents a promotional coupon in the `coupons` collection.
class CouponModel extends Equatable {
  /// The unique ID of the coupon, which is the coupon code customers will use.
  final String id;

  /// A brief description of the offer for admin reference.
  final String description;

  /// Determines if the discount is a percentage or a flat amount.
  final CouponType type;

  /// The numeric value of the discount (e.g., 20 for 20% or 100 for ₹100 off).
  final double value;

  /// The minimum order total required to apply this coupon.
  final double? minOrderValue;

  /// The maximum number of times this coupon can be used in total. Null for unlimited.
  final int? maxUses;

  /// The current number of times this coupon has been used.
  /// This should be updated atomically using a transaction.
  final int usedCount;

  /// The date and time when the coupon expires.
  final Timestamp expiryDate;

  /// A simple flag to enable or disable the coupon without deleting it.
  final bool isActive;

  /// Firestore timestamps for auditing.
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const CouponModel({
    required this.id,
    required this.description,
    required this.type,
    required this.value,
    this.minOrderValue,
    this.maxUses,
    this.usedCount = 0,
    required this.expiryDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a `CouponModel` instance from a Firestore document snapshot.
  factory CouponModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CouponModel(
      id: doc.id,
      description: data['description'] as String? ?? '',
      type: CouponType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => CouponType.fixedAmount,
      ),
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      minOrderValue: (data['minOrderValue'] as num?)?.toDouble(),
      maxUses: (data['maxUses'] as num?)?.toInt(),
      usedCount: (data['usedCount'] as num?)?.toInt() ?? 0,
      expiryDate: data['expiryDate'] as Timestamp? ?? Timestamp.now(),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  /// Converts this `CouponModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'type': type.name,
      'value': value,
      'minOrderValue': minOrderValue,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'expiryDate': expiryDate,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  List<Object?> get props => [id, type, value, expiryDate, isActive, createdAt, updatedAt];
}