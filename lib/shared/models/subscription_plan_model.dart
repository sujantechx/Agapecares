// lib/shared/models/subscription_plan_model.dart

class SubscriptionPlan {
  /// A unique identifier for the subscription plan (e.g., 'hc-monthly-3').
  final String id;

  /// The display name for the plan (e.g., '3-Month Plan').
  final String name;

  /// How often the service is provided (e.g., 'Once a month').
  final String frequencyDetails;

  /// The total duration of the subscription period in months.
  final int durationInMonths;

  /// The discount percentage offered for this subscription.
  final double discount;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.frequencyDetails,
    required this.durationInMonths,
    required this.discount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequencyDetails': frequencyDetails,
      'durationInMonths': durationInMonths,
      'discount': discount,
    };
  }

  static SubscriptionPlan fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const SubscriptionPlan(
        id: '',
        name: '',
        frequencyDetails: '',
        durationInMonths: 1,
        discount: 0.0,
      );
    }

    final durationRaw = map['durationInMonths'];
    final discountRaw = map['discount'];

    final duration = (durationRaw is int)
        ? durationRaw
        : (durationRaw is String)
            ? int.tryParse(durationRaw) ?? 1
            : (durationRaw is num)
                ? durationRaw.toInt()
                : 1;

    final discount = (discountRaw is int)
        ? discountRaw.toDouble()
        : (discountRaw is double)
            ? discountRaw
            : (discountRaw is String)
                ? double.tryParse(discountRaw) ?? 0.0
                : 0.0;

    return SubscriptionPlan(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      frequencyDetails: map['frequencyDetails'] as String? ?? '',
      durationInMonths: duration,
      discount: discount,
    );
  }
}