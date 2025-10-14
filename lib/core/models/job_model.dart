// Minimal JobModel used by worker app pages
import 'package:cloud_firestore/cloud_firestore.dart';

class JobModel {
  final String id;
  final String orderNumber;
  final String serviceName;
  final List<String> inclusions;
  final DateTime scheduledAt;
  final String address;
  final String customerName;
  final String customerPhone;
  final bool isCod;
  String status; // mutable for UI demo: pending/assigned/on_way/arrived/in_progress/paused/completed

  JobModel({
    required this.id,
    required this.orderNumber,
    required this.serviceName,
    required this.inclusions,
    required this.scheduledAt,
    required this.address,
    required this.customerName,
    required this.customerPhone,
    this.isCod = false,
    this.status = 'pending',
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return JobModel(
      id: doc.id,
      orderNumber: data['orderNumber'] as String? ?? '',
      serviceName: data['serviceName'] as String? ?? '',
      inclusions: List<String>.from(data['inclusions'] ?? []),
      scheduledAt: (data['scheduledAt'] is Timestamp) ? (data['scheduledAt'] as Timestamp).toDate() : DateTime.now(),
      address: data['address'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      isCod: data['isCod'] as bool? ?? false,
      status: data['status'] as String? ?? 'pending',
    );
  }
}

