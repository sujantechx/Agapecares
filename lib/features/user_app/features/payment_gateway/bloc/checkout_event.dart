// File: lib/features/user_app/payment_gateway/bloc/checkout_event.dart
import 'package:equatable/equatable.dart';
import '../model/payment_models.dart';

abstract class CheckoutEvent extends Equatable {
  const CheckoutEvent();
  @override
  List<Object?> get props => [];
}

class CheckoutSubmitted extends CheckoutEvent {
  final PaymentRequest request;
  final String paymentMethod; // 'razorpay' or 'cod'
  const CheckoutSubmitted({required this.request, required this.paymentMethod});
  @override
  List<Object?> get props => [request, paymentMethod];
}
