// Admin Worker Management - BLoC
// Purpose: Business logic for admin operations on workers (load, update status, assign jobs).
// Notes: Uses AdminWorkerRepository and core models; no structural model changes.

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/worker_repository.dart';
import 'admin_worker_event.dart';
import 'admin_worker_state.dart';

class AdminWorkerBloc extends Bloc<AdminWorkerEvent, AdminWorkerState> {
  final AdminWorkerRepository repo;
  AdminWorkerBloc({required this.repo}) : super(AdminWorkerInitial()) {
    on<LoadWorkers>((event, emit) async {
      emit(AdminWorkerLoading());
      try {
        final workers = await repo.getAllWorkers();
        emit(AdminWorkerLoaded(workers));
      } catch (e) {
        emit(AdminWorkerError(e.toString()));
      }
    });
    on<SetAvailabilityEvent>((event, emit) async {
      try {
        await repo.setAvailability(workerId: event.workerId, isAvailable: event.isAvailable);
        add(LoadWorkers());
      } catch (e) {
        emit(AdminWorkerError(e.toString()));
      }
    });
    on<DeleteWorkerEvent>((event, emit) async {
      // Deletion of workers via admin UI is disabled. No-op to prevent accidental deletions.
      // If other code emits DeleteWorkerEvent, reload the workers to reflect current state.
      add(LoadWorkers());
    });
  }
}
