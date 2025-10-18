// lib/models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'cart_item_model.dart'; // A simple embedded model, see below

/// Enums for order and payment statuses.
enum OrderStatus { pending, accepted, assigned, in_progress, completed, cancelled }
enum PaymentStatus { pending, paid, failed, refunded }

/// Represents an order document in the `orders` collection.
class OrderModel extends Equatable {
  /// The unique ID of the order document.
  final String id;
  /// A user-friendly order number (e.g., "Agape-1001").
  final String orderNumber;
  /// The UID of the customer who placed the order.
  final String userId;
  /// The UID of the worker assigned to the order. Null if unassigned.
  final String? workerId;

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

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.workerId,
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

    return OrderModel(
      id: doc.id,
      orderNumber: orderNum,
      userId: data['userId'] as String? ?? data['orderOwner'] as String? ?? '',
      workerId: data['workerId'] as String?,
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
    );
  }

  /// Converts this `OrderModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'orderNumber': orderNumber,
      'userId': userId,
      'workerId': workerId,
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
    };
  }

  @override
  List<Object?> get props => [id, orderNumber, userId, workerId, orderStatus, paymentStatus, total];
}