// Admin Worker Repository Implementation
// Purpose: Repository façade for admin worker operations; delegates to AdminWorkerRemoteDataSource.
// Note: Returns/accepts core models and ensures consistent types (no model changes).

import 'package:agapecares/core/models/worker_model.dart';
import '../../domain/repositories/worker_repository.dart';
import '../data_sources/worker_remote_data_source.dart';

class AdminWorkerRepositoryImpl implements AdminWorkerRepository {
  final AdminWorkerRemoteDataSource remote;
  AdminWorkerRepositoryImpl({required this.remote});
  @override
  Future<List<WorkerModel>> getAllWorkers() => remote.getAllWorkers();
  @override
  Future<void> setAvailability({required String workerId, required bool isAvailable}) => remote.setAvailability(workerId: workerId, isAvailable: isAvailable);
  @override
  Future<void> deleteWorker(String workerId) async {
    // Deletion via repository is disabled to prevent accidental removal of worker profiles.
    // Admin UI and BLoC are intentionally prevented from deleting workers.
    // ignore: avoid_print
    print('[AdminWorkerRepository] deleteWorker called for $workerId - operation disabled');
    return;
  }
}
