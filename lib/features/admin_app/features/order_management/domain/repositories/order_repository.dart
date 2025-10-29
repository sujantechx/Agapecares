import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';

abstract class OrderRepository {
  /// Fetch all orders with optional filters. Supported keys: 'status','orderOwner'/'userId','workerId','dateFrom','dateTo','orderNumber','limit'.
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters});
  Future<void> updateOrderStatus({required String orderId, required String status});
  /// Assign a worker to an order. Optionally provide `scheduledAt` to create an appointment and link it to the order.
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName, Timestamp? scheduledAt});
  Future<void> deleteOrder(String orderId);

}
