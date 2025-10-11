import 'dart:convert';

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
  factory ServiceModel.fromMap(Map<String, dynamic>? map) {
    // If the source map is null, return a safe empty model.
    if (map == null) {
      return const ServiceModel(
        id: '',
        name: '',
        description: '',
        price: 0.0,
        originalPrice: 0.0,
        iconUrl: '',
        detailImageUrl: '',
        vendorName: '',
        estimatedTime: '',
        offer: '',
        inclusions: const [],
        exclusions: const [],
        options: const [],
        subscriptionPlans: null,
      );
    }

    // Safe parsing with fallbacks for each field
    List<ServiceOption> options = const <ServiceOption>[];
    try {
      final rawOptions = map['options'];
      if (rawOptions is String && rawOptions.isNotEmpty) {
        // maybe JSON-encoded list
        final decoded = (rawOptions.startsWith('[')) ? List<dynamic>.from(jsonDecode(rawOptions) as List) : <dynamic>[];
        options = decoded.map((e) => ServiceOption.fromMap(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})).toList();
      } else if (rawOptions is List) {
        options = rawOptions.map((e) {
          try {
            if (e is Map) return ServiceOption.fromMap(Map<String, dynamic>.from(e));
            return ServiceOption.fromMap(<String, dynamic>{});
          } catch (_) {
            return ServiceOption.fromMap(<String, dynamic>{});
          }
        }).toList();
      }
    } catch (_) {
      options = const <ServiceOption>[];
    }

    List<SubscriptionPlan>? subs;
    try {
      final rawSubs = map['subscriptionPlans'];
      if (rawSubs is String && rawSubs.isNotEmpty) {
        final decoded = (rawSubs.startsWith('[')) ? List<dynamic>.from(jsonDecode(rawSubs) as List) : <dynamic>[];
        subs = decoded.map((e) => SubscriptionPlan.fromMap(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})).toList();
      } else if (rawSubs is List) {
        subs = rawSubs.map((e) {
          try {
            if (e is Map) return SubscriptionPlan.fromMap(Map<String, dynamic>.from(e));
            return SubscriptionPlan.fromMap(<String, dynamic>{});
          } catch (_) {
            return SubscriptionPlan.fromMap(<String, dynamic>{});
          }
        }).toList();
      } else {
        subs = null;
      }
    } catch (_) {
      subs = null;
    }


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
      inclusions: _coerceStringList(map['inclusions']),
      exclusions: _coerceStringList(map['exclusions']),
      options: options,
      subscriptionPlans: subs,
    );
  }

  // Helper to coerce a dynamic into List<String>
  static List<String> _coerceStringList(dynamic value) {
    try {
      if (value is String && value.isNotEmpty) {
        final decoded = (value.startsWith('[')) ? jsonDecode(value) as List : <dynamic>[];
        return decoded.map((e) => e?.toString() ?? '').toList().cast<String>();
      }
      if (value is List) {
        return value.map((e) => e?.toString() ?? '').toList().cast<String>();
      }
      return <String>[];
    } catch (_) {
      return <String>[];
    }
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