// File: lib/features/user_app/payment_gateway/repository/razorpay_payment_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import '../model/payment_models.dart';

/// Razorpay client: asks backend for order creation and opens checkout.
/// Why: keep secret on server; client uses public/test key only.
class RazorpayPaymentRepository {
  final Razorpay _razorpay = Razorpay();
  final String backendCreateOrderUrl; // e.g. http://10.0.2.2:8080/create-order

  RazorpayPaymentRepository({required this.backendCreateOrderUrl});

  Future<PaymentResult> processPayment(PaymentRequest request) async {
    final completer = Completer<PaymentResult>();

    void successHandler(PaymentSuccessResponse resp) {
      if (!completer.isCompleted) {
        completer.complete(PaymentSuccess(paymentId: resp.paymentId ?? '', orderId: resp.orderId));
      }
    }

    void errorHandler(PaymentFailureResponse resp) {
      if (!completer.isCompleted) {
        completer.complete(PaymentFailure(message: resp.message ?? 'Razorpay error'));
      }
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, successHandler);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, errorHandler);

    try {
      final amountInPaise = (request.totalAmount * 100).toInt();
      final resp = await http.post(
        Uri.parse(backendCreateOrderUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amountInPaise}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Backend failed to create order: ${resp.body}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final orderId = data['id'] as String?;
      if (orderId == null) throw Exception('Order id missing from backend');

      final options = {
        'key': 'rzp_test_RQu49xkKeYszyG', // test key provided
        'amount': amountInPaise,
        'name': 'Agape Cares',
        'order_id': orderId,
        'description': 'Order Payment',
        'prefill': {'contact': request.userPhone, 'email': request.userEmail},
      };

      _razorpay.open(options);
    } catch (e) {
      if (!completer.isCompleted) completer.complete(PaymentFailure(message: 'Could not initiate payment.'));
    }

    final result = await completer.future;
    _razorpay.clear();
    return result;
  }

  void dispose() => _razorpay.clear();
}
