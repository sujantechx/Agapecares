import 'package:equatable/equatable.dart';

class AdminOrderEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadOrders extends AdminOrderEvent {}

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

