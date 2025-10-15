// lib/models/settings_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents the global application settings, stored as a single document
/// in the `settings` collection (e.g., document ID `global`).
class SettingsModel extends Equatable {
  /// The tax percentage to be applied to orders (e.g., 18.0 for 18%).
  final double taxPercent;

  /// The app's currency code (e.g., "INR").
  final String currencyCode;

  /// The app's currency symbol (e.g., "₹").
  final String currencySymbol;

  /// The minimum number of hours before a booking that a user can cancel.
  final int cancellationPolicyHours;

  /// The primary contact email for customer support.
  final String supportEmail;

  const SettingsModel({
    required this.taxPercent,
    required this.currencyCode,
    required this.currencySymbol,
    required this.cancellationPolicyHours,
    required this.supportEmail,
  });

  /// Creates a `SettingsModel` instance from a Firestore document snapshot.
  factory SettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SettingsModel(
      taxPercent: (data['taxPercent'] as num?)?.toDouble() ?? 0.0,
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      currencySymbol: data['currencySymbol'] as String? ?? '₹',
      cancellationPolicyHours: (data['cancellationPolicyHours'] as num?)?.toInt() ?? 24,
      supportEmail: data['supportEmail'] as String? ?? '',
    );
  }

  /// Converts this `SettingsModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'taxPercent': taxPercent,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'cancellationPolicyHours': cancellationPolicyHours,
      'supportEmail': supportEmail,
    };
  }

  @override
  List<Object?> get props => [taxPercent, currencyCode, cancellationPolicyHours];
}