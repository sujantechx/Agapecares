// lib/models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'cart_item_model.dart'; // A simple embedded model, see below

/// Enums for order and payment statuses.
// Added worker-specific statuses so UI, rules and stored strings align.
enum OrderStatus { pending, accepted, assigned, on_my_way, arrived, in_progress, paused, completed, cancelled }
enum PaymentStatus { pending, paid, failed, refunded }

/// Represents an order document in the `orders` collection.
class OrderModel extends Equatable {
  /// The unique ID of the order document.
  final String id;
  /// A user-friendly order number (e.g., "Agape-1001").
  final String orderNumber;
  /// The UID of the customer who placed the order.
  final String userId;
  /// The customer's display name snapshot at order time (optional).
  final String? userName;
  /// The customer's phone snapshot at order time (optional).
  final String? userPhone;
  /// The UID of the worker assigned to the order. Null if unassigned.
  final String? workerId;
  /// The worker's display name snapshot at assignment time (optional).
  final String? workerName;
  /// The worker's phone snapshot at assignment time (optional).
  final String? workerPhone;

  /// A list of items included in the order.
  final List<CartItemModel> items;

  /// The address for the service, stored as a snapshot to prevent changes if the user updates their profile.
  final Map<String, dynamic> addressSnapshot;

  /// The financial details of the order.
  final double subtotal;
  final double discount;
  final double tax;
  final double total;

  /// The current status of the order lifecycle.
  final OrderStatus orderStatus;
  /// The current status of the payment.
  final PaymentStatus paymentStatus;

  /// Optional assignment history (list of maps with timestamps/status changes) and payment reference data.
  final List<Map<String, dynamic>>? assignmentHistory;
  final Map<String, dynamic>? paymentRef;

  /// The date and time the service is scheduled for.
  final Timestamp scheduledAt;
  /// The timestamp when the order was created.
  final Timestamp createdAt;
  /// The timestamp when the order was last updated.
  final Timestamp updatedAt;
  /// Optional user rating for the completed order (1.0 - 5.0). This is the
  /// primary rating for the service quality (most important).
  final double? serviceRating;
  /// Optional rating specifically about the worker (1.0 - 5.0). This is
  /// secondary and may be omitted.
  final double? workerRating;
  final String? appointmentId;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.userName,
    this.userPhone,
    this.workerId,
    this.workerName,
    this.workerPhone,
    required this.items,
    required this.addressSnapshot,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.orderStatus,
    required this.paymentStatus,
    this.assignmentHistory,
    this.paymentRef,
    required this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
    this.serviceRating,
    this.workerRating,
    this.appointmentId,
  });

  /// Creates an `OrderModel` instance from a Firestore document snapshot.
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Support multiple possible field names for totals
    final totalVal = (data['total'] ?? data['totalAmount']) as num?;
    final subtotalVal = (data['subtotal'] ?? 0) as num?;
    final discountVal = (data['discount'] ?? 0) as num?;
    final taxVal = (data['tax'] ?? 0) as num?;

    // Support different order number field names
    final orderNum = (data['orderNumber'] ?? data['orderNo'] ?? '') as String;

    // Support multiple status field names
    final rawOrderStatus = (data['orderStatus'] ?? data['status']) as String? ?? '';
    final rawPaymentStatus = (data['paymentStatus'] ?? data['payment_state'] ?? '') as String? ?? '';

    OrderStatus parsedOrderStatus = OrderStatus.pending;
    if (rawOrderStatus.isNotEmpty) {
      try {
        parsedOrderStatus = OrderStatus.values.firstWhere((e) => e.name == rawOrderStatus);
      } catch (_) {
        // fallback to mapping common strings
        final s = rawOrderStatus.toLowerCase();
        if (s.contains('in_progress') || s.contains('in progress')) parsedOrderStatus = OrderStatus.in_progress;
        else if (s.contains('on_my_way') || s.contains('on my way') || s.contains('onmyway') || s.contains('onway')) parsedOrderStatus = OrderStatus.on_my_way;
        else if (s.contains('arrived')) parsedOrderStatus = OrderStatus.arrived;
        else if (s.contains('paused') || s.contains('pause')) parsedOrderStatus = OrderStatus.paused;
        else if (s.contains('assigned')) parsedOrderStatus = OrderStatus.assigned;
        else if (s.contains('accepted')) parsedOrderStatus = OrderStatus.accepted;
        else if (s.contains('completed')) parsedOrderStatus = OrderStatus.completed;
        else if (s.contains('cancel')) parsedOrderStatus = OrderStatus.cancelled;
        else parsedOrderStatus = OrderStatus.pending;
      }
    }

    PaymentStatus parsedPaymentStatus = PaymentStatus.pending;
    if (rawPaymentStatus.isNotEmpty) {
      try {
        parsedPaymentStatus = PaymentStatus.values.firstWhere((e) => e.name == rawPaymentStatus);
      } catch (_) {
        final s = rawPaymentStatus.toLowerCase();
        if (s.contains('paid')) parsedPaymentStatus = PaymentStatus.paid;
        else if (s.contains('fail')) parsedPaymentStatus = PaymentStatus.failed;
        else if (s.contains('refund')) parsedPaymentStatus = PaymentStatus.refunded;
        else parsedPaymentStatus = PaymentStatus.pending;
      }
    }

    // Parse items safely
    final items = (data['items'] as List<dynamic>?)
        ?.map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    // assignmentHistory may be a list of maps
    List<Map<String, dynamic>>? assignmentHistory;
    if (data['assignmentHistory'] is List) {
      assignmentHistory = (data['assignmentHistory'] as List).map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
    }

    final paymentRef = data['paymentRef'] is Map ? Map<String, dynamic>.from(data['paymentRef'] as Map) : null;

    double? parsedServiceRating;
    double? parsedWorkerRating;
    // Support legacy single 'rating' field as serviceRating for backward compatibility
    if (data['serviceRating'] != null) {
      try {
        parsedServiceRating = (data['serviceRating'] as num).toDouble();
      } catch (_) {
        parsedServiceRating = double.tryParse(data['serviceRating'].toString());
      }
    } else if (data['rating'] != null) {
      try {
        parsedServiceRating = (data['rating'] as num).toDouble();
      } catch (_) {
        parsedServiceRating = double.tryParse(data['rating'].toString());
      }
    }
    if (data['workerRating'] != null) {
      try {
        parsedWorkerRating = (data['workerRating'] as num).toDouble();
      } catch (_) {
        parsedWorkerRating = double.tryParse(data['workerRating'].toString());
      }
    }

    return OrderModel(
      id: doc.id,
      orderNumber: orderNum,
      userId: data['userId'] as String? ?? data['orderOwner'] as String? ?? '',
      userName: data['userName'] as String?,
      userPhone: data['userPhone'] as String?,
      workerId: data['workerId'] as String?,
      workerName: data['workerName'] as String?,
      workerPhone: data['workerPhone'] as String?,
      items: items,
      addressSnapshot: Map<String, dynamic>.from(data['addressSnapshot'] ?? {}),
      subtotal: subtotalVal?.toDouble() ?? 0.0,
      discount: discountVal?.toDouble() ?? 0.0,
      tax: taxVal?.toDouble() ?? 0.0,
      total: totalVal?.toDouble() ?? 0.0,
      orderStatus: parsedOrderStatus,
      paymentStatus: parsedPaymentStatus,
      assignmentHistory: assignmentHistory,
      paymentRef: paymentRef,
      scheduledAt: data['scheduledAt'] as Timestamp? ?? Timestamp.now(),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      serviceRating: parsedServiceRating,
      workerRating: parsedWorkerRating,
      appointmentId: data['appointmentId'] as String?,
    );
  }

  /// Converts this `OrderModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'orderNumber': orderNumber,
      'userId': userId,
      if (userName != null) 'userName': userName,
      if (userPhone != null) 'userPhone': userPhone,
      'workerId': workerId,
      if (workerName != null) 'workerName': workerName,
      if (workerPhone != null) 'workerPhone': workerPhone,
      'items': items.map((item) => item.toMap()).toList(),
      'addressSnapshot': addressSnapshot,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'orderStatus': orderStatus.name,
      'paymentStatus': paymentStatus.name,
      'scheduledAt': scheduledAt,
      'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(), // Automatically set on write
      if (assignmentHistory != null) 'assignmentHistory': assignmentHistory,
      if (paymentRef != null) 'paymentRef': paymentRef,
      if (serviceRating != null) 'serviceRating': serviceRating,
      if (workerRating != null) 'workerRating': workerRating,
      if (appointmentId != null) 'appointmentId': appointmentId,
    };
  }

  /// Create a copy of this order with optional changes (used for status updates).
  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? userId,
    String? userName,
    String? userPhone,
    String? workerId,
    String? workerName,
    String? workerPhone,
    List<CartItemModel>? items,
    Map<String, dynamic>? addressSnapshot,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    OrderStatus? orderStatus,
    PaymentStatus? paymentStatus,
    List<Map<String, dynamic>>? assignmentHistory,
    Map<String, dynamic>? paymentRef,
    Timestamp? scheduledAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    double? serviceRating,
    double? workerRating,
    String? appointmentId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      items: items ?? this.items,
      addressSnapshot: addressSnapshot ?? this.addressSnapshot,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      assignmentHistory: assignmentHistory ?? this.assignmentHistory,
      paymentRef: paymentRef ?? this.paymentRef,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serviceRating: serviceRating ?? this.serviceRating,
      workerRating: workerRating ?? this.workerRating,
      appointmentId: appointmentId ?? this.appointmentId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    userId,
    userName,
    userPhone,
    workerId,
    workerName,
    workerPhone,
    orderStatus,
    paymentStatus,
    total,
    serviceRating,
    workerRating,
    appointmentId,
  ];
}