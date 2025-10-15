// lib/models/service_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// Note: You would create these two files below as well.
import 'service_option_model.dart';
import 'subscription_plan_model.dart';

/// Represents a single cleanable service in the `services` collection.
class ServiceModel extends Equatable {
  /// The unique identifier for the service document.
  final String id;

  /// The display name of the service (e.g., "Full House Deep Clean").
  final String name;

  /// A detailed description of what the service includes.
  final String description;

  /// The category this service belongs to (e.g., "Home Cleaning").
  final String category;

  /// The base price for the service, before any options are selected.
  final double basePrice;

  /// The estimated time in minutes to complete the service.
  final int estimatedTimeMinutes;

  /// URL for the service's primary icon or image.
  final String imageUrl;

  /// List of selectable variations for the service (e.g., "2 BHK", "3 BHK").
  final List<ServiceOption> options;

  /// List of available subscription plans for this service.
  final List<SubscriptionPlan> subscriptionPlans;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.estimatedTimeMinutes,
    required this.imageUrl,
    this.options = const [],
    this.subscriptionPlans = const [],
  });

  /// Creates a `ServiceModel` instance from a Firestore document snapshot.
  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
      options: (data['options'] as List<dynamic>?)
          ?.map((e) => ServiceOption.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      subscriptionPlans: (data['subscriptionPlans'] as List<dynamic>?)
          ?.map((e) => SubscriptionPlan.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  /// Converts this `ServiceModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'basePrice': basePrice,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'imageUrl': imageUrl,
      'options': options.map((o) => o.toMap()).toList(),
      'subscriptionPlans': subscriptionPlans.map((s) => s.toMap()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, name, category, basePrice];

  static fromMap(Map<String, dynamic> data) {}
}