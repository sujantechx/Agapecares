import 'package:equatable/equatable.dart';
import '../../../../../shared/models/service_list_model.dart';
import '../../../../../shared/models/service_option_model.dart';
import '../../../../../shared/models/subscription_plan_model.dart';

class CartItem extends Equatable {
  // A unique ID for the cart item, combining the other IDs.
  final String id;
  final ServiceModel service;
  final ServiceOption selectedOption;
  final SubscriptionPlan? subscription;
  final int quantity;

  const CartItem({
    required this.id,
    required this.service,
    required this.selectedOption,
    this.subscription,
    this.quantity = 1,
  });

  // Helper to calculate the price for this specific cart item instance.
  double get price {
    double basePrice = selectedOption.price;
    if (subscription != null) {
      final discount = subscription!.discount / 100;
      final pricePerService = basePrice * (1 - discount);
      return pricePerService * subscription!.durationInMonths * quantity;
    }
    return basePrice * quantity;
  }

  // Helper to create a new instance with updated values (immutable pattern).
  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      service: service,
      selectedOption: selectedOption,
      subscription: subscription,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  List<Object?> get props => [id, service, selectedOption, subscription, quantity];
}