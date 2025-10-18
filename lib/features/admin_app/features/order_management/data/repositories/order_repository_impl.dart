import 'package:agapecares/core/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../data_sources/order_remote_data_source.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource remote;
  OrderRepositoryImpl({required this.remote});

  @override
  Future<List<OrderModel>> getAllOrders({Map<String, dynamic>? filters}) => remote.getAllOrders(filters: filters);

  @override
  Future<void> updateOrderStatus({required String orderId, required String status}) =>
      remote.updateOrderStatus(orderId: orderId, status: status);

  @override
  Future<void> assignWorker({required String orderId, required String workerId, String? workerName}) =>
      remote.assignWorker(orderId: orderId, workerId: workerId, workerName: workerName);

  @override
  Future<void> deleteOrder(String orderId) => remote.deleteOrder(orderId);
}
