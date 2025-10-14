import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/worker_model.dart';

abstract class AdminWorkerState extends Equatable {
  @override
  List<Object?> get props => [];
}
class AdminWorkerInitial extends AdminWorkerState {}
class AdminWorkerLoading extends AdminWorkerState {}
class AdminWorkerLoaded extends AdminWorkerState {
  final List<WorkerModel> workers;
  AdminWorkerLoaded(this.workers);
  @override
  List<Object?> get props => [workers];
}
class AdminWorkerError extends AdminWorkerState {
  final String message;
  AdminWorkerError(this.message);
  @override
  List<Object?> get props => [message];
}

