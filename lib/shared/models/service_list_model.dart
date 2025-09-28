// lib/shared/models/service_list_model.dart



import 'package:agapecares/shared/models/service_option_model.dart';
import 'package:equatable/equatable.dart';

/// Represents a single service that can be booked.
class ServiceModel extends Equatable {

  final String id;
  final String name;
  final String description; // Used for card on home page
  final double price;
  final String iconUrl; // Used for card on home page

  // 🎯 NEW FIELDS FOR DETAIL PAGE
  final String detailImageUrl;
  final String vendorName;
  final double originalPrice;
  final String estimatedTime;
  final String offer;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<ServiceOption>? options; // 🎯 ADD THIS FIELD (make it nullable)

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.iconUrl,
    // 🎯 NEW FIELDS
    required this.detailImageUrl,
    required this.vendorName,
    required this.originalPrice,
    required this.estimatedTime,
    required this.offer,
    required this.inclusions,
    required this.exclusions,
    this.options, // 🎯 ADD THIS FIELD
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    price,
    iconUrl,
    // 🎯 NEW FIELDS
    detailImageUrl,
    vendorName,
    originalPrice,
    estimatedTime,
    offer,
    inclusions,
    exclusions,
    options,
  ];
}