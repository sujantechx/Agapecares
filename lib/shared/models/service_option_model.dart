// lib/shared/models/service_option_model.dart

import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents a single selectable option for a service, with generic store serialization.
class ServiceOption extends Equatable {
  final String id;
  final String name; // e.g., "5 Seater Sofa"
  final double price;

  const ServiceOption({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ServiceOption.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ServiceOption(id: '', name: '', price: 0.0);
    }

    final dynamic priceValue = map['price'];
    double parsedPrice;
    if (priceValue is int) {
      parsedPrice = priceValue.toDouble();
    } else if (priceValue is double) {
      parsedPrice = priceValue;
    } else if (priceValue is String) {
      parsedPrice = double.tryParse(priceValue) ?? 0.0;
    } else {
      parsedPrice = 0.0;
    }

    return ServiceOption(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: parsedPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  factory ServiceOption.fromJson(String source) =>
      ServiceOption.fromMap(json.decode(source) as Map<String, dynamic>?);

  String toJson() => json.encode(toMap());

  ServiceOption copyWith({
    String? id,
    String? name,
    double? price,
  }) {
    return ServiceOption(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }

  @override
  List<Object?> get props => [id, name, price];
}