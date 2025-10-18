// User-facing WorkerRepository implementation that delegates to the admin worker remote data source

import 'package:agapecares/core/models/worker_model.dart';
import 'package:agapecares/features/user_app/features/workers/domain/repositories/worker_repository.dart';
import 'package:agapecares/features/admin_app/features/worker_management/data/data_sources/worker_remote_data_source.dart' as admin_worker_ds;

class WorkerRepositoryImpl implements WorkerRepository {
  final admin_worker_ds.AdminWorkerRemoteDataSource remote;
  WorkerRepositoryImpl({required this.remote});

  @override
  Future<List<WorkerModel>> getAllWorkers() => remote.getAllWorkers();
}

