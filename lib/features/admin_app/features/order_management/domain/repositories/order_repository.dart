import 'package:agapecares/core/models/order_model.dart';

abstract class OrderRepository {
  /// Fetch all orders with optional filters. Supported keys: 'status','orderOwner'/'userId','workerId','dateFrom','dateTo','orderNumber','limit'.
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters});
  Future<void> updateOrderStatus({required String orderId, required String status});
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName});
  Future<void> deleteOrder(String orderId);

}
