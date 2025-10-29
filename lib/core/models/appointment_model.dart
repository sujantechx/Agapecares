// filepath: c:/FlutterDev/agapecares/lib/core/models/appointment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum AppointmentStatus { scheduled, confirmed, rescheduled, cancelled, completed }

class AppointmentModel extends Equatable {
  final String id;
  final String orderId;
  final String userId;
  final String? workerId;
  final Timestamp scheduledAt;
  final Timestamp? startAt;
  final Timestamp? endAt;
  final int? durationMinutes;
  final AppointmentStatus status;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const AppointmentModel({
    required this.id,
    required this.orderId,
    required this.userId,
    this.workerId,
    required this.scheduledAt,
    this.startAt,
    this.endAt,
    this.durationMinutes,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawStatus = (data['status'] as String?) ?? 'scheduled';

    AppointmentStatus parsedStatus = AppointmentStatus.scheduled;
    try {
      parsedStatus = AppointmentStatus.values.firstWhere((e) => e.name == rawStatus);
    } catch (_) {
      final s = rawStatus.toLowerCase();
      if (s.contains('confirm')) parsedStatus = AppointmentStatus.confirmed;
      else if (s.contains('resched')) parsedStatus = AppointmentStatus.rescheduled;
      else if (s.contains('cancel')) parsedStatus = AppointmentStatus.cancelled;
      else if (s.contains('complete')) parsedStatus = AppointmentStatus.completed;
    }

    return AppointmentModel(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      workerId: data['workerId'] as String?,
      scheduledAt: data['scheduledAt'] as Timestamp? ?? Timestamp.now(),
      startAt: data['startAt'] as Timestamp?,
      endAt: data['endAt'] as Timestamp?,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
      status: parsedStatus,
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'workerId': workerId,
      'scheduledAt': scheduledAt,
      if (startAt != null) 'startAt': startAt,
      if (endAt != null) 'endAt': endAt,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      'status': status.name,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  AppointmentModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? workerId,
    Timestamp? scheduledAt,
    Timestamp? startAt,
    Timestamp? endAt,
    int? durationMinutes,
    AppointmentStatus? status,
    String? notes,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      workerId: workerId ?? this.workerId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, orderId, userId, workerId, scheduledAt, startAt, endAt, status, notes];
}

