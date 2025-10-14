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
  Future<void> deleteWorker(String workerId) => remote.deleteWorker(workerId);
}

