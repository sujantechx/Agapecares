// File: lib/features/user_app/payment_gateway/model/payment_models.dart
/// Simple payment request/result models.
/// Why: isolate payment domain and keep repositories decoupled.

class PaymentRequest {
  final double totalAmount; // in rupees
  final String userEmail;
  final String userPhone;
  final String userName;
  final List<dynamic> items; // UI cart items (should map to CartItemModel)

  PaymentRequest({
    required this.totalAmount,
    required this.userEmail,
    required this.userPhone,
    required this.userName,
    required this.items,
  });
}

/// Result types
abstract class PaymentResult {
  const PaymentResult();
}

class PaymentSuccess extends PaymentResult {
  final String paymentId;
  final String? orderId;
  const PaymentSuccess({required this.paymentId, this.orderId});
}

class PaymentFailure extends PaymentResult {
  final String message;
  const PaymentFailure({required this.message});
}
