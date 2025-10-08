// lib/shared/models/service_list_model.dart (Updated)

import './service_option_model.dart';
import './subscription_plan_model.dart'; // <-- Import the new model

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double originalPrice;
  final String iconUrl;
  final String detailImageUrl;
  final String vendorName;
  final String estimatedTime;
  final String offer;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<ServiceOption> options;
  final List<SubscriptionPlan>? subscriptionPlans; // <-- ADD THIS LINE

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.iconUrl,
    required this.detailImageUrl,
    required this.vendorName,
    required this.estimatedTime,
    required this.offer,
    required this.inclusions,
    required this.exclusions,
    required this.options,
    this.subscriptionPlans, // <-- ADD THIS LINE to the constructor
  });
}