// lib/models/payout_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum for the status of a payout to a worker.
enum PayoutStatus { pending, processing, completed, failed }

/// Represents a payout made to a worker, stored in the `payouts` collection.
/// This tracks the money your business pays out to your service professionals.
class PayoutModel extends Equatable {
  /// The unique ID of the payout transaction.
  final String id;

  /// The UID of the worker receiving the payout.
  final String workerId;

  /// The total amount being paid out.
  final double amount;

  /// The currency of the payout.
  final String currency;

  /// The current status of the payout transaction.
  final PayoutStatus status;

  /// The start date of the earning period this payout covers.
  final Timestamp periodStartDate;

  /// The end date of the earning period this payout covers.
  final Timestamp periodEndDate;

  /// The UID of the admin who initiated this payout.
  final String initiatedBy;

  /// Timestamp for when the payout was initiated by an admin.
  final Timestamp initiatedAt;

  /// Timestamp for when the payout was successfully completed.
  final Timestamp? completedAt;

  /// A map to store transaction details from the payment processor (e.g., bank transfer ID).
  final Map<String, dynamic>? transactionDetails;

  const PayoutModel({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.initiatedBy,
    required this.initiatedAt,
    this.completedAt,
    this.transactionDetails,
  });

  /// Creates a `PayoutModel` instance from a Firestore document snapshot.
  factory PayoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PayoutModel(
      id: doc.id,
      workerId: data['workerId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'INR',
      status: PayoutStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => PayoutStatus.pending,
      ),
      periodStartDate: data['periodStartDate'] as Timestamp? ?? Timestamp.now(),
      periodEndDate: data['periodEndDate'] as Timestamp? ?? Timestamp.now(),
      initiatedBy: data['initiatedBy'] as String? ?? '',
      initiatedAt: data['initiatedAt'] as Timestamp? ?? Timestamp.now(),
      completedAt: data['completedAt'] as Timestamp?,
      transactionDetails: data['transactionDetails'] != null
          ? Map<String, dynamic>.from(data['transactionDetails'])
          : null,
    );
  }

  /// Converts this `PayoutModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'workerId': workerId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'periodStartDate': periodStartDate,
      'periodEndDate': periodEndDate,
      'initiatedBy': initiatedBy,
      'initiatedAt': initiatedAt,
      'completedAt': completedAt,
      'transactionDetails': transactionDetails,
    };
  }

  @override
  List<Object?> get props => [id, workerId, status, periodStartDate, periodEndDate];
}