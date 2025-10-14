// File: lib/features/user_app/payment_gateway/repository/cod_payment_repository.dart
import '../model/payment_models.dart';

/// Cash on Delivery repository: trivial implementation.
/// Why: uniform interface for payment flows; easier to test.
class CodPaymentRepository {
  Future<PaymentResult> processCod(PaymentRequest request) async {
    // No external calls; immediate success for order flow.
    return const PaymentSuccess(paymentId: 'COD', orderId: null);
  }
}
