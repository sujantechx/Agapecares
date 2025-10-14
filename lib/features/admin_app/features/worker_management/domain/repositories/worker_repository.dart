import 'package:agapecares/core/models/worker_model.dart';

abstract class AdminWorkerRepository {
  Future<List<WorkerModel>> getAllWorkers();
  Future<void> setAvailability({required String workerId, required bool isAvailable});
  Future<void> deleteWorker(String workerId);
}
