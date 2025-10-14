import '../../../../../shared/models/order_model.dart';

abstract class OrderRepository {
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true});
  Future<String> generateOrderNumber();
  Future<void> uploadOrder(OrderModel localOrder);
  Future<List<OrderModel>> fetchOrdersForUser(String userId);
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId);
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters});
}

