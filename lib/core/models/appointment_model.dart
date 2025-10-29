// Lightweight appointment model to optionally link appointments to orders.
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String orderId;
  final String workerId;
  final Timestamp scheduledAt; // timestamp at 09:00 local date (date-only semantics)
  final String startTime; // e.g. '09:00'
  final String endTime; // e.g. '18:00'

  AppointmentModel({
    required this.id,
    required this.orderId,
    required this.workerId,
    required this.scheduledAt,
    this.startTime = '09:00',
    this.endTime = '18:00',
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppointmentModel(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      workerId: data['workerId'] as String? ?? '',
      scheduledAt: data['scheduledAt'] as Timestamp? ?? Timestamp.now(),
      startTime: data['startTime'] as String? ?? '09:00',
      endTime: data['endTime'] as String? ?? '18:00',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'workerId': workerId,
      'scheduledAt': scheduledAt,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}
