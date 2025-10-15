// Admin Worker Management - Events
// Purpose: Events that trigger admin worker operations (load, accept job, set availability, etc.).
// Notes: Events should map to repository methods implemented in admin worker repo.

import 'package:equatable/equatable.dart';

abstract class AdminWorkerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
class LoadWorkers extends AdminWorkerEvent {}
class SetAvailabilityEvent extends AdminWorkerEvent {
  final String workerId;
  final bool isAvailable;
  SetAvailabilityEvent({required this.workerId, required this.isAvailable});
  @override
  List<Object?> get props => [workerId, isAvailable];
}
class DeleteWorkerEvent extends AdminWorkerEvent {
  final String workerId;
  DeleteWorkerEvent(this.workerId);
  @override
  List<Object?> get props => [workerId];
}
