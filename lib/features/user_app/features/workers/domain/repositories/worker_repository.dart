// User-facing worker repository interface
// Purpose: Allow user-side code to fetch workers without depending on admin-only types.

import 'package:agapecares/core/models/worker_model.dart';

abstract class WorkerRepository {
  /// Fetch all available workers.
  Future<List<WorkerModel>> getAllWorkers();
}

