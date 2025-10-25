// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\logic\blocs\worker_tasks_state.dart

import 'package:equatable/equatable.dart';
import '../../../../core/models/order_model.dart';

abstract class WorkerTasksState extends Equatable {
  const WorkerTasksState();

  @override
  List<Object?> get props => [];
}

class WorkerTasksInitial extends WorkerTasksState {}

class WorkerTasksLoading extends WorkerTasksState {}

class WorkerTasksLoaded extends WorkerTasksState {
  final List<OrderModel> upcoming;
  final List<OrderModel> today;
  final List<OrderModel> past;

  const WorkerTasksLoaded({required this.upcoming, required this.today, required this.past});

  @override
  List<Object?> get props => [upcoming, today, past];
}

class WorkerTasksEmpty extends WorkerTasksState {}

class WorkerTasksFailure extends WorkerTasksState {
  final String message;
  const WorkerTasksFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class WorkerTasksUpdating extends WorkerTasksState {}

class WorkerTasksUpdateSuccess extends WorkerTasksState {}

class WorkerTasksUpdateFailure extends WorkerTasksState {
  final String message;
  const WorkerTasksUpdateFailure(this.message);

  @override
  List<Object?> get props => [message];
}

