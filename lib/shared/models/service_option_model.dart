// lib/shared/models/service_option_model.dart


import 'package:equatable/equatable.dart';

/// Represents a single selectable option for a service.
class ServiceOption extends Equatable {
  final String id;
  final String name; // e.g., "5 Seater Sofa"
  final double price;

  const ServiceOption({
    required this.id,
    required this.name,
    required this.price,
  });

  @override
  List<Object?> get props => [id, name, price];
}