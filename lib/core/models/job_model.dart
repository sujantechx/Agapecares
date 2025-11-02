// filepath: lib/core/models/job_model.dart
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal JobModel used by worker UI components.
/// This intentionally contains only fields referenced by the UI.
class JobModel extends Equatable {
  final String id;
  final String serviceName;
  final String address;
  final String customerName;
  final String customerPhone;
  final DateTime scheduledAt;
  final DateTime? scheduledEnd;
  final String? specialInstructions;
  final double? rating;
  final String status; // e.g. 'pending','assigned','on_way','arrived','in_progress','paused','completed'
  final bool isCod;
  final String? paymentStatus; // e.g. 'pending','paid','cod'
  final Map<String, dynamic>? paymentRef; // optional payment reference details
  final double? total;
  final List<String> inclusions;
  final String? orderNumber;

  const JobModel({
    required this.id,
    required this.serviceName,
    required this.address,
    required this.customerName,
    required this.customerPhone,
    required this.scheduledAt,
    this.scheduledEnd,
    this.specialInstructions,
    this.rating,
    required this.status,
    this.isCod = false,
    this.paymentStatus,
    this.paymentRef,
    this.total,
    this.inclusions = const [],
    this.orderNumber,
  });

  factory JobModel.fromMap(Map<String, dynamic>? map, {String? id}) {
    final m = map ?? {};
    return JobModel(
      id: id ?? (m['id'] as String? ?? ''),
      serviceName: m['serviceName'] as String? ?? (m['service'] as String? ?? ''),
      address: m['address'] as String? ?? '',
      customerName: m['customerName'] as String? ?? (m['userName'] as String? ?? ''),
      customerPhone: m['customerPhone'] as String? ?? (m['userPhone'] as String? ?? ''),
      scheduledAt: _parseTimestamp(m['scheduledAt'] ?? m['scheduled_at']) ?? DateTime.now(),
      status: m['status'] as String? ?? 'pending',
      isCod: m['isCod'] as bool? ?? (m['is_cod'] as bool? ?? false),
      paymentStatus: m['paymentStatus'] as String? ?? m['payment_state'] as String?,
      paymentRef: m['paymentRef'] is Map ? Map<String, dynamic>.from(m['paymentRef'] as Map) : null,
      total: (m['total'] is num)
          ? (m['total'] as num).toDouble()
          : (m['totalAmount'] is num)
              ? (m['totalAmount'] as num).toDouble()
              : (m['total_amount'] is num)
                  ? (m['total_amount'] as num).toDouble()
                  : (m['totalAmount'] != null ? double.tryParse(m['totalAmount'].toString()) : null),
      scheduledEnd: _parseTimestamp(m['scheduledEnd'] ?? m['scheduled_end']),
      specialInstructions: m['specialInstructions'] as String? ?? m['special_instructions'] as String?,
      rating: (m['rating'] is num) ? (m['rating'] as num).toDouble() : (m['rating'] != null ? double.tryParse(m['rating'].toString()) : null),
      inclusions: (m['inclusions'] is List) ? List<String>.from(m['inclusions'].map((e) => e?.toString() ?? '')) : const [],
      orderNumber: m['orderNumber'] as String? ?? m['remoteId'] as String?,
    );
  }

  factory JobModel.fromFirestore(DocumentSnapshot doc) => JobModel.fromMap(doc.data() as Map<String, dynamic>?, id: doc.id);

  Map<String, dynamic> toMap() => {
        'id': id,
        'serviceName': serviceName,
        'address': address,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'scheduledEnd': scheduledEnd != null ? Timestamp.fromDate(scheduledEnd!) : null,
        'status': status,
        'isCod': isCod,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (paymentRef != null) 'paymentRef': paymentRef,
        'total': total,
        'inclusions': inclusions,
        if (orderNumber != null) 'orderNumber': orderNumber,
        'specialInstructions': specialInstructions,
        'rating': rating,
      };

  static DateTime? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  JobModel copyWith({
    String? id,
    String? serviceName,
    String? address,
    String? customerName,
    String? customerPhone,
    DateTime? scheduledAt,
    DateTime? scheduledEnd,
    String? specialInstructions,
    double? rating,
    String? status,
    bool? isCod,
    String? paymentStatus,
    Map<String, dynamic>? paymentRef,
    double? total,
    List<String>? inclusions,
    String? orderNumber,
  }) {
    return JobModel(
      id: id ?? this.id,
      serviceName: serviceName ?? this.serviceName,
      address: address ?? this.address,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      isCod: isCod ?? this.isCod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentRef: paymentRef ?? this.paymentRef,
      total: total ?? this.total,
      inclusions: inclusions ?? this.inclusions,
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }

  @override
  List<Object?> get props => [id, serviceName, address, customerName, customerPhone, scheduledAt, status, isCod, inclusions, paymentStatus, paymentRef, total, orderNumber];
}
