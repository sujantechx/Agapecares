// Minimal WorkerOrderDetailPage used by router (accepts orderId param)
import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/core/models/job_model.dart';
import 'package:intl/intl.dart';

class WorkerOrderDetailPage extends StatefulWidget {
  final String orderId;
  const WorkerOrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<WorkerOrderDetailPage> createState() => _WorkerOrderDetailPageState();
}

class _WorkerOrderDetailPageState extends State<WorkerOrderDetailPage> {
  final WorkerJobRepository _repo = WorkerJobRepository();
  JobModel? _job;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() => _loading = true);
    try {
      // Defensive: if the route param is missing or still the placeholder ":id",
      // avoid calling Firestore which may result in permission-denied errors
      // and unnecessary reads. Show 'Job not found' instead.
      if (widget.orderId.isEmpty || widget.orderId.contains(':')) {
        debugPrint('[WorkerOrderDetailPage] invalid orderId provided: "${widget.orderId}"');
        setState(() => _job = null);
        return;
      }
      final j = await _repo.getJobById(widget.orderId);
      setState(() => _job = j);
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] loadJob error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load job: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_job == null) return;
    try {
      final updated = await _repo.updateJobStatus(_job!.id, status);
      if (updated != null) {
        setState(() => _job = updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${updated.status}')));
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] changeStatus error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  List<Widget> _buildActionButtons() {
    if (_job == null) return [];
    final status = _job!.status;
    final List<Widget> buttons = [];

    void add(String label, String to, {Color? color}) {
      buttons.add(ElevatedButton(
        onPressed: () => _changeStatus(to),
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(label),
      ));
    }

    switch (status) {
      case 'pending':
        add('Accept', 'assigned', color: Colors.orange);
        break;
      case 'assigned':
        add('On My Way', 'on_way', color: Colors.blue);
        add('Arrived', 'arrived', color: Colors.green);
        break;
      case 'on_way':
        add('Arrived', 'arrived', color: Colors.green);
        break;
      case 'arrived':
        add('Start', 'in_progress', color: Colors.teal);
        add('Pause', 'paused', color: Colors.grey);
        break;
      case 'in_progress':
        add('Pause', 'paused', color: Colors.grey);
        add('Complete', 'completed', color: Colors.green);
        break;
      case 'paused':
        add('Resume', 'in_progress', color: Colors.teal);
        add('Complete', 'completed', color: Colors.green);
        break;
      default:
        // no actions
        break;
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _job == null
              ? const Center(child: Text('Job not found'))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_job!.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_job!.address)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.schedule, size: 18, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(DateFormat.yMMMMd().add_jm().format(_job!.scheduledAt.toLocal())),
                      ]),
                      if (_job!.scheduledEnd != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_outlined, size: 18, color: Colors.black54),
                          const SizedBox(width: 8),
                          Text('Ends: ${DateFormat.yMMMMd().add_jm().format(_job!.scheduledEnd!.toLocal())}'),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      Text('Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${_job!.customerName} • ${_job!.customerPhone}'),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Payment: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_job!.isCod)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.amber.withAlpha((0.12 * 255).round())), child: const Text('COD', style: TextStyle(color: Colors.amber)))
                        else
                          const Text('Prepaid'),
                      ]),
                      const SizedBox(height: 12),
                      if (_job!.specialInstructions != null && _job!.specialInstructions!.isNotEmpty) ...[
                        const Text('Special Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(_job!.specialInstructions!),
                        const SizedBox(height: 12),
                      ],
                      const Text('Inclusions', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: _job!.inclusions.map((i) => Chip(label: Text(i))).toList()),
                      const SizedBox(height: 8),
                      if (_job!.rating != null) ...[
                        Row(children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text('Rating: ${_job!.rating!.toStringAsFixed(1)}'),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _buildActionButtons(),
                      )
                    ],
                  ),
                ),
    );
  }
}
