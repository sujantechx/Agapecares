import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/core/models/job_model.dart';

class AcceptJobUsecase {
  final WorkerJobRepository repository;

  AcceptJobUsecase(this.repository);

  /// Accept or update a job status. Returns updated JobModel or throws if failed.
  Future<JobModel> call(String jobId, String newStatus) async {
    final updated = await repository.updateJobStatus(jobId, newStatus);
    if (updated == null) throw Exception('Job not found');
    return updated;
  }
}

