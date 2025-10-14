import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

class OrderModel {
  final String? id;
  final String userId;
  final List<CartItemModel> items;
  final String orderNumber;
  final String paymentStatus;
  final String paymentMethod;
  final String? paymentId;
  final double subtotal;
  final double discount;
  final double total;
  final String orderStatus;
  final String? workerId;
  final String? workerName;
  final Timestamp? acceptedAt;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final int? localId;

  // Additional fields used across repositories and services
  final bool isSynced;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAddress;
  final double? rating;
  final String? review;
  final String? remoteId;

  OrderModel({
    this.id,
    required this.userId,
    required this.items,
    required this.orderNumber,
    this.paymentStatus = 'pending',
    required this.paymentMethod,
    this.paymentId,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    this.orderStatus = 'pending',
    this.workerId,
    this.workerName,
    this.acceptedAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    this.localId,
    this.isSynced = false,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAddress,
    this.rating,
    this.review,
    this.remoteId,
  })  : createdAt = createdAt ?? Timestamp.now(),
        updatedAt = updatedAt ?? Timestamp.now();

  /// Create from Firestore document snapshot
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => cartItemFromMap(item is Map ? Map<String, dynamic>.from(item) : null))
              .toList() ??
          [],
      orderNumber: data['orderNumber'] ?? '',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? 'cod',
      paymentId: data['paymentId'],
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      discount: (data['discount'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      orderStatus: data['orderStatus'] ?? 'pending',
      workerId: data['workerId'],
      workerName: data['workerName'],
      acceptedAt: data['acceptedAt'] is Timestamp ? data['acceptedAt'] : null,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      localId: data['localId'],
      isSynced: true,
      userName: data['userName'] as String?,
      userEmail: data['userEmail'] as String?,
      userPhone: data['userPhone'] as String?,
      userAddress: data['userAddress'] as String?,
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : (data['rating'] is String ? double.tryParse('${data['rating']}') : null),
      review: data['review'] as String?,
      remoteId: data['remoteId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toFirestore()).toList(),
      'orderNumber': orderNumber,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentId': paymentId,
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'orderStatus': orderStatus,
      'workerId': workerId,
      'workerName': workerName,
      'acceptedAt': acceptedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'localId': localId,
      'isSynced': isSynced,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'userAddress': userAddress,
      'rating': rating,
      'review': review,
      'remoteId': remoteId,
    };
  }

  /// Backwards-compatible alias used in repositories
  Map<String, dynamic> toFirebaseJson() => toFirestore();

  /// Create OrderModel from a map stored in local sqlite
  static OrderModel fromSqliteMap(Map<String, dynamic> m) {
    // createdAt/updatedAt may be stored as int ms since epoch, string, or Timestamp
    Timestamp parseTs(dynamic v) {
      if (v == null) return Timestamp.now();
      if (v is Timestamp) return v;
      if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return Timestamp.fromMillisecondsSinceEpoch(parsed);
        return Timestamp.now();
      }
      return Timestamp.now();
    }

    final itemsRaw = (m['items'] as List<dynamic>?) ?? <dynamic>[];
    final items = itemsRaw.map((e) {
      if (e is Map<String, dynamic>) return CartItemModel.fromMap(e);
      if (e is Map) return CartItemModel.fromMap(Map<String, dynamic>.from(e));
      return CartItemModel.fromMap(null);
    }).toList();

    return OrderModel(
      localId: m['localId'] as int?,
      isSynced: (m['isSynced'] == 1 || m['isSynced'] == true),
      id: m['id'] as String?,
      userId: m['userId'] as String? ?? '',
      items: items.cast<CartItemModel>(),
      subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (m['discount'] as num?)?.toDouble() ?? 0.0,
      total: (m['total'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: m['paymentStatus'] as String? ?? 'pending',
      paymentMethod: m['paymentMethod'] as String? ?? 'cod',
      paymentId: m['paymentId'] as String?,
      orderNumber: m['orderNumber'] as String? ?? '',
      orderStatus: m['orderStatus'] as String? ?? 'pending',
      userName: m['userName'] as String?,
      userEmail: m['userEmail'] as String?,
      userPhone: m['userPhone'] as String?,
      userAddress: m['userAddress'] as String?,
      workerId: m['workerId'] as String?,
      workerName: m['workerName'] as String?,
      acceptedAt: m['acceptedAt'] is Timestamp ? m['acceptedAt'] : null,
      createdAt: parseTs(m['createdAt']),
      updatedAt: parseTs(m['updatedAt']),
      rating: (m['rating'] is num) ? (m['rating'] as num).toDouble() : null,
      review: m['review'] as String?,
      remoteId: m['remoteId'] as String?,
    );
  }

  static CartItemModel cartItemFromMap(Map<String, dynamic>? data) {
    // Delegate to CartItemModel.fromMap which correctly builds ServiceOption
    return CartItemModel.fromMap(data);
  }
  OrderModel copyWith({
    String? id,
    String? userId,
    List<CartItemModel>? items,
    String? orderNumber,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentId,
    double? subtotal,
    double? discount,
    double? total,
    String? orderStatus,
    String? workerId,
    String? workerName,
    Timestamp? acceptedAt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    int? localId,
    bool? isSynced,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userAddress,
    double? rating,
    String? review,
    String? remoteId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      orderNumber: orderNumber ?? this.orderNumber,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      orderStatus: orderStatus ?? this.orderStatus,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localId: localId ?? this.localId,
      isSynced: isSynced ?? this.isSynced,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userAddress: userAddress ?? this.userAddress,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      remoteId: remoteId ?? this.remoteId,
    );
  }
}
