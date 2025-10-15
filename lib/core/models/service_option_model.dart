// lib/models/service_option_model.dart
import 'package:equatable/equatable.dart';

/// Represents a selectable option for a service, like size or type.
/// This is embedded inside a `ServiceModel` document.
class ServiceOption extends Equatable {
  final String name; // e.g., "5 Seater Sofa"
  final double price; // The price for this specific option

  const ServiceOption({required this.name, required this.price});

  factory ServiceOption.fromMap(Map<String, dynamic> map) {
    return ServiceOption(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  @override
  List<Object?> get props => [name, price];
}


