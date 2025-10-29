import 'package:flutter/material.dart';
import 'package:agapecares/features/admin_app/features/order_management/domain/repositories/order_repository.dart' as admin_order_repo;
import 'package:agapecares/core/models/order_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart' as admin_events;
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectOrderForWorkerDialog extends StatefulWidget {
  final String workerId;
  final String? workerName;
  const SelectOrderForWorkerDialog({Key? key, required this.workerId, this.workerName}) : super(key: key);

  @override
  State<SelectOrderForWorkerDialog> createState() => _SelectOrderForWorkerDialogState();
}

class _SelectOrderForWorkerDialogState extends State<SelectOrderForWorkerDialog> {
  List<OrderModel>? _orders;
  bool _loading = true;
  String? _error;
  OrderModel? _selected;
  bool _assigning = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = context.read<admin_order_repo.OrderRepository>();
      // Prefer pending orders that are not yet assigned
      final list = await repo.getAllOrders(filters: {'status': 'pending', 'limit': 200});
      setState(() { _orders = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _assign() async {
    if (_selected == null) return;
    setState(() { _assigning = true; });
    final repo = context.read<admin_order_repo.OrderRepository>();
    try {
      final ts = _selectedDate != null ? Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 9, 0)) : null; // fixed 09:00 start
      await repo.assignWorker(orderId: _selected!.id, workerId: widget.workerId, workerName: widget.workerName, scheduledAt: ts);
      try { context.read<AdminOrderBloc>().add(admin_events.AssignWorkerEvent(orderId: _selected!.id, workerId: widget.workerId, workerName: widget.workerName, scheduledAt: ts)); } catch (_) {}
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned worker to order')));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _assigning = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign worker: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign worker to order'),
      content: SizedBox(
        width: 600,
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : (_error != null)
                ? Column(mainAxisSize: MainAxisSize.min, children: [Text('Failed to load orders: $_error'), const SizedBox(height: 12), ElevatedButton(onPressed: _loadOrders, child: const Text('Retry'))])
                : (_orders == null || _orders!.isEmpty)
                    ? const Text('No available orders to assign')
                    : SizedBox(
                        height: 360,
                        child: ListView.separated(
                          itemCount: _orders!.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final o = _orders![i];
                            return ListTile(
                              title: Text(o.orderNumber.isNotEmpty ? o.orderNumber : o.id),
                              subtitle: Text('User: ${o.userId} • ₹${o.total.toStringAsFixed(2)}'),
                              selected: _selected?.id == o.id,
                              onTap: () => setState(() => _selected = o),
                            );
                          },
                        ),
                      ),
      ),
      actions: [
        // Schedule picker control (date-only, time fixed to 09:00)
        Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Show date-only and fixed work hours (09:00 - 18:00)
            Text(_selectedDate == null ? 'No schedule' : '${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year} • Work hours: 09:00 - 18:00'),
            TextButton(onPressed: () => _pickDate(context), child: const Text('Pick date')),
          ]),
        ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_selected == null || _assigning) ? null : _assign,
          child: _assigning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
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
