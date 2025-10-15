import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'order_remote_data_source.dart';

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  @override
  Future<List<OrderModel>> getAllOrders() async {
    try {
      final snap = await _orders.orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => OrderModel.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      // Surface permission errors more clearly to the caller
      if (e.code == 'permission-denied' || e.message?.toLowerCase().contains('permission') == true) {
        throw Exception('Firestore permission denied when fetching orders. Check Firestore rules and ensure your account has admin access. (${e.message})');
      }
      throw Exception('Failed to fetch orders: ${e.message}');
    }
  }

  @override
  Future<void> updateOrderStatus({required String orderId, required String status}) async {
    try {
      await _orders.doc(orderId).update({
        'orderStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied updating order. Are your Firestore rules allowing admins to update orders?');
      }
      rethrow;
    }
  }

  @override
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName}) async {
    try {
      await _orders.doc(orderId).update({
        'workerId': workerId,
        if (workerName != null) 'workerName': workerName,
        'orderStatus': 'assigned',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied assigning worker. Check Firestore rules.');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    try {
      await _orders.doc(orderId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied deleting order. Check Firestore rules.');
      }
      rethrow;
    }
  }
}
