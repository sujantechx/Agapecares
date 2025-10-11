// File: lib/features/user_app/payment_gateway/repository/razorpay_payment_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import '../model/payment_models.dart';
import 'package:flutter/foundation.dart';

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
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        final body = resp.body;
        debugPrint('[RazorpayPaymentRepository] backend create-order failed: ${resp.statusCode} ${body}');
        // Fallback: try opening checkout without server order_id so devs can test Razorpay UI.
        final optionsFallback = {
          'key': 'rzp_test_RQu49xkKeYszyG',
          'amount': amountInPaise,
          'name': 'Agape Cares',
          'description': 'Order Payment',
          'prefill': {'contact': request.userPhone, 'email': request.userEmail},
        };
        try {
          _razorpay.open(optionsFallback);
        } catch (e) {
          if (!completer.isCompleted) completer.complete(PaymentFailure(message: 'Failed to open Razorpay checkout (fallback): ${e.toString()}'));
        }
      } else {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final orderId = data['id'] as String?;
        if (orderId == null) {
          debugPrint('[RazorpayPaymentRepository] backend response missing id: ${resp.body}');
          // Fallback: open without order_id
          final optionsFallback = {
            'key': 'rzp_test_RQu49xkKeYszyG',
            'amount': amountInPaise,
            'name': 'Agape Cares',
            'description': 'Order Payment',
            'prefill': {'contact': request.userPhone, 'email': request.userEmail},
          };
          try {
            _razorpay.open(optionsFallback);
          } catch (e) {
            if (!completer.isCompleted) completer.complete(PaymentFailure(message: 'Failed to open Razorpay checkout (missing id): ${e.toString()}'));
          }
        } else {
          final options = {
            'key': 'rzp_test_RQu49xkKeYszyG', // test key provided
            'amount': amountInPaise,
            'name': 'Agape Cares',
            'order_id': orderId,
            'description': 'Order Payment',
            'prefill': {'contact': request.userPhone, 'email': request.userEmail},
          };

          // open checkout UI
          try {
            _razorpay.open(options);
          } catch (e) {
            if (!completer.isCompleted) completer.complete(PaymentFailure(message: 'Failed to open Razorpay checkout: ${e.toString()}'));
          }
        }
      }
    } catch (e) {
      debugPrint('[RazorpayPaymentRepository] exception while creating order: ${e.toString()}');
      // As a last resort try opening checkout without server order id so developers can test UI
      final amountInPaise = (request.totalAmount * 100).toInt();
      final optionsFallback = {
        'key': 'rzp_test_RQu49xkKeYszyG',
        'amount': amountInPaise,
        'name': 'Agape Cares',
        'description': 'Order Payment',
        'prefill': {'contact': request.userPhone, 'email': request.userEmail},
      };
      try {
        _razorpay.open(optionsFallback);
      } catch (e2) {
        if (!completer.isCompleted) completer.complete(PaymentFailure(message: 'Could not initiate payment: ${e.toString()} / fallback failed: ${e2.toString()}'));
      }
    }

    // Wait for payment result but don't hang forever if callbacks never arrive
    final result = await completer.future.timeout(const Duration(minutes: 2), onTimeout: () {
      debugPrint('[RazorpayPaymentRepository] payment timeout or no callback received');
      return const PaymentFailure(message: 'Payment timed out or was cancelled');
    });
    _razorpay.clear();
    return result;
  }

  void dispose() => _razorpay.clear();
}
