import 'package:equatable/equatable.dart';

class AdminOrderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Load orders. Optional `filters` map supports keys: 'status','orderOwner'/'userId','workerId','dateFrom'(DateTime),'dateTo'(DateTime),'orderNumber','limit'
class LoadOrders extends AdminOrderEvent {
  final Map<String, dynamic>? filters;
  LoadOrders({this.filters});

  @override
  List<Object?> get props => [filters];
}

class UpdateOrderStatusEvent extends AdminOrderEvent {
  final String orderId;
  final String status;
  UpdateOrderStatusEvent(this.orderId, this.status);
  @override
  List<Object?> get props => [orderId, status];
}

class AssignWorkerEvent extends AdminOrderEvent {
  final String orderId;
  final String workerId;
  final String? workerName;
  AssignWorkerEvent({required this.orderId, required this.workerId, this.workerName});
  @override
  List<Object?> get props => [orderId, workerId, workerName];
}

class DeleteOrderEvent extends AdminOrderEvent {
  final String orderId;
  DeleteOrderEvent(this.orderId);
  @override
  List<Object?> get props => [orderId];
}
