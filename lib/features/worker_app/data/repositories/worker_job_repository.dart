import 'package:agapecares/core/models/job_model.dart';

class WorkerJobRepository {
  // Keep an in-memory list so status updates can be demonstrated in UI
  final List<JobModel> _jobs = [];
  bool _initialized = false;

  WorkerJobRepository();

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    final now = DateTime.now();
    _jobs.addAll([
      JobModel(
        id: 'job1',
        serviceName: 'Full Home Cleaning',
        inclusions: ['Deep cleaning', 'Floor polishing', 'Window cleaning'],
        scheduledAt: now.add(const Duration(hours: 3)),
        address: '12, Green Street, Bhubaneswar',
        customerName: 'Ramesh',
        customerPhone: '+919876543210',
        isCod: true,
        status: 'assigned',
      ),
      JobModel(
        id: 'job2',
        serviceName: 'Sofa Deep Cleaning',
        inclusions: ['Shampoo', 'Spot treatment'],
        scheduledAt: now,
        address: '5, Lakeview Colony',
        customerName: 'Sita',
        customerPhone: '+919812345678',
        isCod: false,
        status: 'on_way',
      ),
      JobModel(
        id: 'job3',
        serviceName: 'Bathroom Deep Cleaning',
        inclusions: ['Disinfection', 'Tile scrubbing'],
        scheduledAt: now.subtract(const Duration(days: 1)),
        address: '88, Market Road',
        customerName: 'Amit',
        customerPhone: '+919900112233',
        isCod: false,
        status: 'completed',
      ),
    ]);
  }

  Future<List<JobModel>> getAssignedJobs() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _ensureInit();
    // Return a shallow copy to avoid external mutation
    return List<JobModel>.from(_jobs);
  }

  Future<JobModel?> getJobById(String id) async {
    _ensureInit();
    try {
      return _jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Update the job status and return the updated JobModel or null if not found
  Future<JobModel?> updateJobStatus(String id, String status) async {
    _ensureInit();
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx == -1) return null;
    // JobModel is immutable, use copyWith to create updated instance
    final updated = _jobs[idx].copyWith(status: status);
    _jobs[idx] = updated;
    // Simulate small delay as if network/db call
    await Future.delayed(const Duration(milliseconds: 120));
    return _jobs[idx];
  }
}
