// Admin Worker Remote DataSource interface
// Purpose: Declares Firestore operations for worker management (list, update, jobs, etc.).
// Note: Works with `WorkerModel` and `UserModel` where appropriate.

import 'package:agapecares/core/models/worker_model.dart';

abstract class AdminWorkerRemoteDataSource {
  Future<List<WorkerModel>> getAllWorkers();
  Future<void> setAvailability({required String workerId, required bool isAvailable});
  Future<void> deleteWorker(String workerId);
}
