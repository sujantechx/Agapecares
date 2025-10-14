import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/models/order_model.dart';
import 'order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final FirebaseFirestore _firestore;

  OrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true}) async {
    if (uploadRemote) {
      await _firestore
          .collection('users')
          .doc(order.userId)
          .collection('orders')
          .add(order.toFirestore());
    }
    // TODO: Handle local storage
  }

  @override
  Future<List<OrderModel>> fetchOrdersForAdmin(
      {Map<String, dynamic>? filters}) {
    // TODO: implement fetchOrdersForAdmin
    throw UnimplementedError();
  }

  @override
  Future<List<OrderModel>> fetchOrdersForUser(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('orders')
        .get();
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId) {
    // TODO: implement fetchOrdersForWorker
    throw UnimplementedError();
  }

  @override
  Future<String> generateOrderNumber() async {
    final now = DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd').format(now);
    final counterDoc = _firestore.collection('order_counters').doc(datePrefix);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterDoc);

      int newSeq;
      if (!snapshot.exists) {
        newSeq = 1;
      } else {
        newSeq = (snapshot.data()!['seq'] ?? 0) + 1;
      }

      transaction.set(counterDoc, {'seq': newSeq, 'updatedAt': FieldValue.serverTimestamp()});

      final suffix = (newSeq + 99).toString().padLeft(5, '0');
      return '$datePrefix$suffix';
    });
  }

  @override
  Future<void> uploadOrder(OrderModel localOrder) {
    // TODO: implement uploadOrder
    throw UnimplementedError();
  }
}

