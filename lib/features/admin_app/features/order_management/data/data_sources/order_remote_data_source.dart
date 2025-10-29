import 'package:agapecares/core/models/order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class OrderRemoteDataSource {
  /// Fetch all orders with optional server-side filters. Supported filter keys:
  /// - 'status' (String)
  /// - 'orderOwner' or 'userId' (String)
  /// - 'workerId' (String)
  /// - 'dateFrom' (DateTime or Timestamp)
  /// - 'dateTo' (DateTime or Timestamp)
  /// - 'orderNumber' (String)
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters});
  Future<void> updateOrderStatus({required String orderId, required String status});
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName, Timestamp? scheduledAt});
  Future<void> deleteOrder(String orderId);
}
