import 'package:equatable/equatable.dart';
/// Represents a subscription plan for a service.
/// This is embedded inside a `ServiceModel` document.
class SubscriptionPlan extends Equatable {
  final String name; // e.g., "3-Month Plan"
  final int durationInMonths;
  final double discountPercent;

  const SubscriptionPlan({required this.name, required this.durationInMonths, required this.discountPercent});

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      name: map['name'] as String? ?? '',
      durationInMonths: (map['durationInMonths'] as num?)?.toInt() ?? 1,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'durationInMonths': durationInMonths,
    'discountPercent': discountPercent,
  };

  @override
  List<Object?> get props => [name, durationInMonths, discountPercent];
}