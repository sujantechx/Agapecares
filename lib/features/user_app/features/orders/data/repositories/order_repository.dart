import '../../../../../../core/models/order_model.dart';

abstract class OrderRepository {
  /// Create order. If `uploadRemote` is true the implementation may upload
  /// to Firestore; when creating a top-level order clients should pass `userId`
  /// (order owner) so server rules accept the write.
  Future<void> createOrder(OrderModel order, {bool uploadRemote = true, String? userId});
  Future<String> generateOrderNumber();
  Future<String> uploadOrder(OrderModel localOrder);
  Future<List<OrderModel>> fetchOrdersForUser(String userId);
  Future<List<OrderModel>> fetchOrdersForWorker(String workerId);
  Future<List<OrderModel>> fetchOrdersForAdmin({Map<String, dynamic>? filters});
}
