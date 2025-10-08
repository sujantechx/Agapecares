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
}