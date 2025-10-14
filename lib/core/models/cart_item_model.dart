import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/service_option_model.dart';

class CartItemModel extends Equatable {
  final String id; // Unique ID for the cart item itself
  final String serviceId;
  final String serviceName;
  final double unitPrice;
  final int quantity;
  final ServiceOption selectedOption;
  final Map<String, dynamic>? options;

  const CartItemModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.unitPrice,
    required this.quantity,
    required this.selectedOption, Map<String, dynamic>? options,
  }) : options = options;

  factory CartItemModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const CartItemModel(
        id: '',
        serviceId: '',
        serviceName: '',
        unitPrice: 0.0,
        quantity: 1,
        selectedOption: ServiceOption(id: '', name: '', price: 0.0),
      );
    }

    return CartItemModel(
      id: map['id'] as String? ?? '',
      serviceId: map['serviceId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      selectedOption: ServiceOption.fromMap(map['selectedOption'] as Map<String, dynamic>?),
      options: map['options'] != null ? Map<String, dynamic>.from(map['options']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'selectedOption': selectedOption.toMap(),
      'options': options,
    };
  }

  /// Alias for writing to Firestore
  Map<String, dynamic> toFirestore() => toMap();

  /// Construct from a Firestore document snapshot
  factory CartItemModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String id) {
    return CartItemModel.fromMap(doc.data());
  }

  CartItemModel copyWith({
    String? id,
    String? serviceId,
    String? serviceName,
    double? unitPrice,
    int? quantity,
    ServiceOption? selectedOption,
    Map<String, dynamic>? options,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      selectedOption: selectedOption ?? this.selectedOption,
      options: options ?? this.options,
    );
  }

  // Backwards-compatible aliases used by older UI code
  String get service => serviceName;
  double get price => unitPrice;

  /// JSON helpers to match code that expects `fromJson`/`toJson`.
  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  @override
  List<Object?> get props =>
      [id, serviceId, serviceName, unitPrice, quantity, selectedOption, options];

  @override
  String toString() {
    return 'CartItemModel(id: $id, serviceId: $serviceId, serviceName: $serviceName, unitPrice: $unitPrice, quantity: $quantity, selectedOption: $selectedOption, options: $options)';
  }
}