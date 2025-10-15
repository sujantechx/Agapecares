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
    required this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an `OrderModel` instance from a Firestore document snapshot.
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return OrderModel(
      id: doc.id,
      orderNumber: data['orderNumber'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      workerId: data['workerId'] as String?,
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => CartItemModel.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      addressSnapshot: Map<String, dynamic>.from(data['addressSnapshot'] ?? {}),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      orderStatus: OrderStatus.values.firstWhere(
            (e) => e.name == data['orderStatus'],
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
            (e) => e.name == data['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
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
    };
  }

  @override
  List<Object?> get props => [id, orderNumber, userId, workerId, orderStatus, paymentStatus];
}