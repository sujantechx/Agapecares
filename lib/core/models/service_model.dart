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

  /// URL for the service's primary icon or image. Kept for compatibility.
  final String imageUrl;

  /// A list of image URLs for the service (preferred for multiple images).
  final List<String> images;

  /// List of selectable variations for the service (e.g., "2 BHK", "3 BHK").
  final List<ServiceOption> options;

  /// List of available subscription plans for this service.
  final List<SubscriptionPlan> subscriptionPlans;

  /// Firestore server timestamp when the document was created. May be null
  /// when creating a local instance before write completes.
  final Timestamp? createdAt;

  /// Firestore server timestamp when the document was last updated.
  final Timestamp? updatedAt;

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.estimatedTimeMinutes,
    this.imageUrl = '',
    this.images = const [],
    this.options = const [],
    this.subscriptionPlans = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a `ServiceModel` instance from a Firestore document snapshot.
  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Try to read images array first; fall back to single imageUrl field.
    final imagesList = (data['images'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ??
        ([]);
    final imageUrlFromDoc = data['imageUrl'] as String? ?? '';
    final resolvedImageUrl = imageUrlFromDoc.isNotEmpty ? imageUrlFromDoc : (imagesList.isNotEmpty ? imagesList.first : '');

    return ServiceModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toInt() ?? 0,
      imageUrl: resolvedImageUrl,
      images: imagesList,
      options: (data['options'] as List<dynamic>?)
          ?.map((e) => ServiceOption.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      subscriptionPlans: (data['subscriptionPlans'] as List<dynamic>?)
          ?.map((e) => SubscriptionPlan.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  /// Create from a plain map. Useful when you only have the document data
  /// (for example `doc.data()`), which may not include the document id.
  /// If the map contains an `id` field it will be used; otherwise `id` will
  /// be an empty string. Prefer using `fromFirestore` when you have the
  /// `DocumentSnapshot` so the `id` is preserved.
  static ServiceModel fromMap(Map<String, dynamic> data) {
    final imagesList = (data['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
    final imageUrlFromMap = data['imageUrl'] as String? ?? '';
    final resolvedImageUrl = imageUrlFromMap.isNotEmpty ? imageUrlFromMap : (imagesList.isNotEmpty ? imagesList.first : '');

    return ServiceModel(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0.0,
      estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toInt() ?? 0,
      imageUrl: resolvedImageUrl,
      images: imagesList,
      options: (data['options'] as List<dynamic>?)
          ?.map((e) => ServiceOption.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      subscriptionPlans: (data['subscriptionPlans'] as List<dynamic>?)
          ?.map((e) => SubscriptionPlan.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
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
      'images': images,
      'options': options.map((o) => o.toMap()).toList(),
      'subscriptionPlans': subscriptionPlans.map((s) => s.toMap()).toList(),
      // timestamps are intentionally not set here to allow repositories to
      // control whether to write server timestamps using FieldValue.serverTimestamp().
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  List<Object?> get props => [id, name, category, basePrice, imageUrl, images, createdAt, updatedAt];
}