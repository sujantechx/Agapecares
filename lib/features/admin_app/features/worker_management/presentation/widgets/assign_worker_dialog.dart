import 'package:flutter/material.dart';
import 'package:agapecares/features/admin_app/features/worker_management/domain/repositories/worker_repository.dart';
import 'package:agapecares/core/models/worker_model.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart' as admin_events;
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/features/admin_app/features/order_management/domain/repositories/order_repository.dart' as admin_order_repo;

/// Dialog that fetches workers and allows the admin to pick one, view details
/// and confirm assignment for the given `orderId`.
class AssignWorkerDialog extends StatefulWidget {
  final String orderId;
  const AssignWorkerDialog({Key? key, required this.orderId}) : super(key: key);

  @override
  State<AssignWorkerDialog> createState() => _AssignWorkerDialogState();
}

class _AssignWorkerDialogState extends State<AssignWorkerDialog> {
  List<WorkerModel>? _workers;
  String? _error;
  bool _loading = true;
  WorkerModel? _selected;
  Map<String, dynamic>? _selectedUserData;
  DateTime? _selectedDate;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = context.read<AdminWorkerRepository>();
      final list = await repo.getAllWorkers();
      setState(() { _workers = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _selectWorker(WorkerModel w) async {
    setState(() { _selected = w; _selectedUserData = null; });
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(w.uid).get();
      setState(() { _selectedUserData = snap.exists ? (snap.data() as Map<String, dynamic>) : null; });
    } catch (_) {
      setState(() { _selectedUserData = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Worker'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : (_error != null)
                ? Column(mainAxisSize: MainAxisSize.min, children: [Text('Failed to load workers: $_error'), const SizedBox(height: 12), ElevatedButton(onPressed: _loadWorkers, child: const Text('Retry'))])
                : (_workers == null || _workers!.isEmpty)
                    ? const Text('No workers found')
                    : Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _workers!.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final w = _workers![i];
                                return ListTile(
                                  title: Text(w.uid),
                                  subtitle: Text('${w.status.name} • ${w.ratingAvg.toStringAsFixed(1)}★ (${w.ratingCount})'),
                                  selected: _selected?.uid == w.uid,
                                  onTap: () => _selectWorker(w),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: _selected == null
                                ? const Center(child: Text('Select a worker to view details'))
                                : Column(children: [Expanded(child: _buildSelectedDetails()), const SizedBox(height:8), _buildSchedulePicker(context)]),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_selected == null || _assigning) ? null : () async {
            setState(() => _assigning = true);
            final orderRepo = context.read<admin_order_repo.OrderRepository>();
            final workerName = _selectedUserData != null ? (_selectedUserData!['name'] as String?) : null;
            try {
              final ts = _selectedDate != null ? Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 9, 0)) : null; // fixed 09:00 start
              await orderRepo.assignWorker(orderId: widget.orderId, workerId: _selected!.uid, workerName: workerName, scheduledAt: ts);
              try { context.read<AdminOrderBloc>().add(admin_events.AssignWorkerEvent(orderId: widget.orderId, workerId: _selected!.uid, workerName: workerName, scheduledAt: ts)); } catch (_) {}
              if (mounted) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker assigned successfully')));
              }
            } catch (e) {
              if (mounted) {
                setState(() => _assigning = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign worker: $e')));
              }
            }
          },
          child: _assigning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }

  Widget _buildSelectedDetails() {
    final w = _selected!;
    final user = _selectedUserData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UID: ${w.uid}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Status: ${w.status.name}'),
        Text('Rating: ${w.ratingAvg.toStringAsFixed(1)} (${w.ratingCount})'),
        const SizedBox(height: 8),
        Text('Skills: ${w.skills.join(', ')}'),
        const SizedBox(height: 12),
        const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (user == null) const Text('No profile data available') else Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Name: ${user['name'] ?? ''}'),
          Text('Email: ${user['email'] ?? ''}'),
          Text('Phone: ${user['phoneNumber'] ?? ''}'),
        ]),
      ],
    );
  }

  Widget _buildSchedulePicker(BuildContext context) {
    // Display only the selected date and show fixed work hours (09:00 - 18:00)
    final display = _selectedDate == null ? 'No schedule (assign now)' : '${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year} • Work hours: 09:00 - 18:00';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Schedule (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Row(children: [Expanded(child: Text(display)), const SizedBox(width: 8), OutlinedButton(onPressed: () => _pickDate(context), child: const Text('Pick date'))]),
    ]);
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 90)));
    if (date == null) return;
    final scheduledDt = DateTime(date.year, date.month, date.day, 9, 0);
    if (scheduledDt.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected schedule (09:00) is in the past. Please pick a future date.')));
      return;
    }
    // Time is fixed to 09:00 (start of workday)
    setState(() { _selectedDate = DateTime(date.year, date.month, date.day); });
  }

}
