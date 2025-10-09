// File: lib/shared/models/order_model.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../features/user_app/cart/data/models/cart_item_model.dart';

/// OrderModel used across app, local sqlite, and Firestore.
/// Why: single source of truth for order serialization and conversion.
class OrderModel extends Equatable {
  final int? localId; // sqlite autoincrement id
  final bool isSynced; // synced to remote
  final String? id; // Firestore id / Razorpay order id (optional)
  final String userId;
  final List<CartItemModel> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final String? paymentId;
  final String orderStatus;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String userAddress;
  final Timestamp createdAt;

  const OrderModel({
    this.localId,
    this.isSynced = false,
    this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    this.paymentId,
    this.orderStatus = 'Placed',
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userAddress,
    required this.createdAt,
  });

  OrderModel copyWith({
    int? localId,
    bool? isSynced,
    String? id,
    String? paymentId,
    String? orderStatus,
  }) {
    return OrderModel(
      localId: localId ?? this.localId,
      isSynced: isSynced ?? this.isSynced,
      id: id ?? this.id,
      userId: userId,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paymentMethod: paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      orderStatus: orderStatus ?? this.orderStatus,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      userAddress: userAddress,
      createdAt: createdAt,
    );
  }

  /// Firestore JSON
  Map<String, dynamic> toFirebaseJson() {
    return {
      'userId': userId,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'orderStatus': orderStatus,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userAddress': userAddress,
      'createdAt': createdAt,
    };
  }

  /// Generic JSON (for UI/debug)
  Map<String, dynamic> toJson() => toFirebaseJson();

  /// SQLite representation; store items as JSON string and createdAt as ISO.
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': localId, // SQLite autoincrement - remove when inserting to let DB assign
      'isSynced': isSynced ? 1 : 0,
      'id_str': id, // remote id (firestore/razorpay) if present
      'userId': userId,
      'itemsJson': jsonEncode(items.map((i) => i.toJson()).toList()),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'orderStatus': orderStatus,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userAddress': userAddress,
      'createdAt': createdAt.toDate().toIso8601String(),
    };
  }

  factory OrderModel.fromSqliteMap(Map<String, dynamic> map) {
    final itemsJson = map['itemsJson'] as String? ?? '[]';
    final decoded = (jsonDecode(itemsJson) as List).cast<Map<String, dynamic>>();
    final itemsList = decoded.map((j) => CartItemModel.fromJson(j)).toList();

    return OrderModel(
      localId: (map['id'] is int) ? map['id'] as int : int.tryParse('${map['id']}'),
      isSynced: (map['isSynced'] == 1),
      id: map['id_str'] as String?,
      userId: map['userId'] as String,
      items: itemsList,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      paymentId: map['paymentId'] as String?,
      orderStatus: map['orderStatus'] as String,
      userName: map['userName'] as String,
      userEmail: map['userEmail'] as String,
      userPhone: map['userPhone'] as String,
      userAddress: map['userAddress'] as String,
      createdAt: Timestamp.fromDate(DateTime.parse(map['createdAt'] as String)),
    );
  }

  @override
  List<Object?> get props => [localId, isSynced, id, userId, items, total];
}
