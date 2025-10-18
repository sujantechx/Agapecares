import 'package:flutter/material.dart';
import 'package:agapecares/features/admin_app/features/order_management/domain/repositories/order_repository.dart' as admin_order_repo;
import 'package:agapecares/core/models/order_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart' as admin_events;

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
      await repo.assignWorker(orderId: _selected!.id, workerId: widget.workerId, workerName: widget.workerName);
      try { context.read<AdminOrderBloc>().add(admin_events.AssignWorkerEvent(orderId: _selected!.id, workerId: widget.workerId, workerName: widget.workerName)); } catch (_) {}
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_selected == null || _assigning) ? null : _assign,
          child: _assigning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Assign'),
        ),
      ],
    );
  }
}

