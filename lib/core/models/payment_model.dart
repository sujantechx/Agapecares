// lib/models/payment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum for the payment method used.
enum PaymentMethod { razorpay, cod, wallet }

/// Enum for the status of a payment transaction.
enum PaymentTransactionStatus { pending, successful, failed, refunded }

/// Represents a payment transaction document in the `payments` collection.
class PaymentModel extends Equatable {
  /// The unique ID for the payment document, often the transaction ID from the payment gateway.
  final String id;

  /// The ID of the order this payment is associated with.
  final String orderId;

  /// The UID of the user who made the payment.
  final String userId;

  /// The total amount of the transaction.
  final double amount;

  /// The currency used for the transaction (e.g., "INR").
  final String currency;

  /// The method used for payment.
  final PaymentMethod method;

  /// The current status of the transaction.
  final PaymentTransactionStatus paymentStatus;

  /// The transaction ID provided by the payment gateway (e.g., Razorpay Payment ID).
  final String? gatewayTransactionId;

  /// A map to store the raw response from the payment gateway for debugging and verification.
  final Map<String, dynamic>? gatewayResponse;

  /// Timestamp for when the payment was initiated.
  final Timestamp createdAt;

  const PaymentModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.paymentStatus,
    this.gatewayTransactionId,
    this.gatewayResponse,
    required this.createdAt,
  });

  /// Creates a `PaymentModel` instance from a Firestore document snapshot.
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'INR',
      method: PaymentMethod.values.firstWhere(
            (e) => e.name == data['method'],
        orElse: () => PaymentMethod.cod,
      ),
      paymentStatus: PaymentTransactionStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => PaymentTransactionStatus.pending,
      ),
      gatewayTransactionId: data['gatewayTransactionId'] as String?,
      gatewayResponse: data['gatewayResponse'] != null ? Map<String, dynamic>.from(data['gatewayResponse']) : null,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts this `PaymentModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'paymentStatus': paymentStatus.name,
      'gatewayTransactionId': gatewayTransactionId,
      'gatewayResponse': gatewayResponse,
      'createdAt': createdAt,
    };
  }

  @override
  List<Object?> get props => [id, orderId, userId, paymentStatus, gatewayTransactionId];
}