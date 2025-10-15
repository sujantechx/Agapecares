// lib/models/cart_item_model.dart
import 'package:equatable/equatable.dart';

/// Represents a single line item within an order.
/// This is embedded in an `OrderModel` document.
class CartItemModel extends Equatable {
  final String serviceId;
  final String serviceName; // Snapshot of the service name
  final String optionName; // Snapshot of the selected option name, if any
  final int quantity;
  final double unitPrice; // Snapshot of the price at time of booking

  const CartItemModel({
    required this.serviceId,
    required this.serviceName,
    required this.optionName,
    required this.quantity,
    required this.unitPrice,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      serviceId: map['serviceId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      optionName: map['optionName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'serviceId': serviceId,
    'serviceName': serviceName,
    'optionName': optionName,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  @override
  List<Object?> get props => [serviceId, optionName, quantity];
}