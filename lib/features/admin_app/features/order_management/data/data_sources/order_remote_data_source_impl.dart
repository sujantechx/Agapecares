import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'order_remote_data_source.dart';

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  @override
  Future<List<OrderModel>> getAllOrders() async {
    final snap = await _orders.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
  }

  @override
  Future<void> updateOrderStatus({required String orderId, required String status}) async {
    await _orders.doc(orderId).update({
      'orderStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName}) async {
    await _orders.doc(orderId).update({
      'workerId': workerId,
      if (workerName != null) 'workerName': workerName,
      'orderStatus': 'assigned',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    await _orders.doc(orderId).delete();
  }
}

