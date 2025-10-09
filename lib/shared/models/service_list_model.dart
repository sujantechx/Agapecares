import './service_option_model.dart';
import './subscription_plan_model.dart';

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
  final List<SubscriptionPlan>? subscriptionPlans;

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
    this.subscriptionPlans,
  });
// Create from a generic Map (suitable for converting Firebase document data or local store maps)
  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0.0,
      iconUrl: map['iconUrl'] as String? ?? '',
      detailImageUrl: map['detailImageUrl'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? '',
      estimatedTime: map['estimatedTime'] as String? ?? '',
      offer: map['offer'] as String? ?? '',
      inclusions: List<String>.from(map['inclusions'] as List? ?? const []),
      exclusions: List<String>.from(map['exclusions'] as List? ?? const []),
      options: (map['options'] as List?)
          ?.map<ServiceOption>((e) => ServiceOption.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList() ??
          const [],
      subscriptionPlans: (map['subscriptionPlans'] as List?)
          ?.map<SubscriptionPlan>((e) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  // Convert to a Map suitable for storing in local store or Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'iconUrl': iconUrl,
      'detailImageUrl': detailImageUrl,
      'vendorName': vendorName,
      'estimatedTime': estimatedTime,
      'offer': offer,
      'inclusions': inclusions,
      'exclusions': exclusions,
      'options': options.map((o) => o.toMap()).toList(),
      if (subscriptionPlans != null)
        'subscriptionPlans': subscriptionPlans!.map((p) => p.toMap()).toList(),
    };
  }
}