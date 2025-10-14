import 'package:agapecares/core/models/order_model.dart';

abstract class OrderRepository {
  Future<List<OrderModel>> getAllOrders();
  Future<void> updateOrderStatus({required String orderId, required String status});
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName});
  Future<void> deleteOrder(String orderId);
}

