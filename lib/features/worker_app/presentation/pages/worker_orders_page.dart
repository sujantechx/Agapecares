import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/features/worker_app/presentation/widgets/job_card.dart';
import 'package:agapecares/core/models/job_model.dart';

class WorkerOrdersPage extends StatefulWidget {
  const WorkerOrdersPage({Key? key}) : super(key: key);

  @override
  State<WorkerOrdersPage> createState() => _WorkerOrdersPageState();
}

class _WorkerOrdersPageState extends State<WorkerOrdersPage> {
  final WorkerJobRepository _repo = WorkerJobRepository();
  List<JobModel> _jobs = [];
  bool _loading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getAssignedJobs();
      setState(() => _jobs = list);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadJobs error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load jobs: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(JobModel job, String newStatus) async {
    try {
      final updated = await _repo.updateJobStatus(job.id, newStatus);
      if (updated != null) {
        final idx = _jobs.indexWhere((j) => j.id == job.id);
        if (idx != -1) {
          setState(() => _jobs[idx] = updated);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${updated.status}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job not found')));
      }
    } catch (e) {
      debugPrint('[WorkerOrdersPage] updateStatus error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _jobs.where((j) => j.status != 'completed').toList();
    final history = _jobs.where((j) => j.status == 'completed').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Availability', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(_isOnline ? 'Online' : 'Offline', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Switch(value: _isOnline, onChanged: (v) => setState(() => _isOnline = v)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Upcoming & Assigned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (upcoming.isEmpty)
                    const Text('No upcoming jobs')
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: ListView.builder(
                          itemCount: upcoming.length,
                          itemBuilder: (context, index) {
                            final job = upcoming[index];
                            return JobCard(
                              job: job,
                              onChangeStatus: (newStatus) => _updateStatus(job, newStatus),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('Work History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    const Text('No completed jobs yet')
                  else
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final j = history[i];
                          return ListTile(
                            title: Text(j.serviceName),
                            subtitle: Text('${j.address} • ${j.customerName}'),
                            trailing: Text(j.scheduledAt.toLocal().toString().split('.').first),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
