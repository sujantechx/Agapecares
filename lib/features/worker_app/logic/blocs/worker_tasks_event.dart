// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\logic\blocs\worker_tasks_event.dart

import 'package:equatable/equatable.dart';
import '../../../../core/models/order_model.dart';

abstract class WorkerTasksEvent extends Equatable {
  const WorkerTasksEvent();

  @override
  List<Object?> get props => [];
}

/// Trigger initial load / reload of worker orders.
class LoadWorkerOrders extends WorkerTasksEvent {
  final bool forceRefresh;
  const LoadWorkerOrders({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class RefreshWorkerOrders extends WorkerTasksEvent {}

/// Ask the worker bloc to update an order's status.
class UpdateOrderStatus extends WorkerTasksEvent {
  final OrderModel order;
  final OrderStatus newStatus;

  const UpdateOrderStatus({required this.order, required this.newStatus});

  @override
  List<Object?> get props => [order, newStatus];
}

