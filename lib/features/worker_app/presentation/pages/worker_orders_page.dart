import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/features/worker_app/presentation/widgets/job_card.dart';

import '../../../../core/models/job_model.dart';


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
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final avail = await _repo.getAvailability();
      if (avail != null) setState(() => _isOnline = avail);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadAvailability error: $e');
    }
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
        } else {
          // refresh list
          await _loadJobs();
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

  Future<void> _setAvailability(bool v) async {
    setState(() => _isOnline = v);
    try {
      await _repo.setAvailability(v);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? 'You are now Online' : 'You are now Offline')));
    } catch (e) {
      debugPrint('[WorkerOrdersPage] setAvailability error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set availability: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final upcoming = _jobs.where((j) => j.scheduledAt.isAfter(todayEnd) && j.status != 'completed').toList();
    final today = _jobs.where((j) => j.scheduledAt.isAfter(todayStart) && j.scheduledAt.isBefore(todayEnd) && j.status != 'completed').toList();
    final history = _jobs.where((j) => j.status == 'completed' || j.scheduledAt.isBefore(todayStart)).toList();

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
                          Switch(value: _isOnline, onChanged: (v) => _setAvailability(v)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (upcoming.isEmpty && today.isEmpty)
                    const Text('No upcoming jobs')
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: ListView(
                          children: [
                            if (today.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ...today.map((j) => JobCard(job: j, onChangeStatus: (s) => _updateStatus(j, s))).toList(),
                            ],

                            if (upcoming.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Upcoming', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ...upcoming.map((j) => JobCard(job: j, onChangeStatus: (s) => _updateStatus(j, s))).toList(),
                            ],

                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Work History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            if (history.isEmpty) const Padding(padding: EdgeInsets.all(8.0), child: Text('No completed jobs yet')),
                            ...history.map((j) => ListTile(
                                  title: Text(j.serviceName),
                                  subtitle: Text('${j.address} • ${j.customerName}'),
                                  trailing: Text(j.scheduledAt.toLocal().toString().split('.').first),
                                  onTap: () {
                                    Navigator.of(context).pushNamed('/worker/orders/${j.id}');
                                  },
                                )),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
