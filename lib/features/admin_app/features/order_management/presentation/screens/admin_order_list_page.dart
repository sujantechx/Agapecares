// Admin order management page
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart' as admin_events;
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_state.dart';
import 'package:intl/intl.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/pages/admin_order_detail_page.dart';
import 'package:agapecares/app/routes/route_helpers.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/features/admin_app/features/worker_management/presentation/widgets/assign_worker_dialog.dart';

class AdminOrderListPage extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  const AdminOrderListPage({Key? key, this.initialFilters}) : super(key: key);

  @override
  State<AdminOrderListPage> createState() => _AdminOrderListPageState();
}

class _AdminOrderListPageState extends State<AdminOrderListPage> {
  Map<String, dynamic>? _filters;

  @override
  void initState() {
    super.initState();
    // load initial unfiltered list or with provided initial filters
    _filters = widget.initialFilters;
    context.read<AdminOrderBloc>().add(admin_events.LoadOrders(filters: _filters));
  }

  void _openFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OrderFilterDialog(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      context.read<AdminOrderBloc>().add(admin_events.LoadOrders(filters: _filters));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Orders'),
        actions: [
          IconButton(onPressed: _openFilterDialog, icon: const Icon(Icons.filter_list)),
          IconButton(
            onPressed: () => context.read<AdminOrderBloc>().add(admin_events.LoadOrders(filters: _filters)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<AdminOrderBloc, AdminOrderState>(
        builder: (context, state) {
          if (state is AdminOrderLoading) return const Center(child: CircularProgressIndicator());
          if (state is AdminOrderError) return Center(child: Text('Error: ${state.message}'));
          if (state is AdminOrderLoaded) {
            if (state.orders.isEmpty) return const Center(child: Text('No orders found'));
            return ListView.builder(
              itemCount: state.orders.length,
              itemBuilder: (context, i) {
                final o = state.orders[i];
                return ListTile(
                  title: Text(o.orderNumber.isNotEmpty ? o.orderNumber : o.id),
                  subtitle: Text('Status: ${o.orderStatus.name.toUpperCase()} • User: ${o.userId}\nCreated: ${o.createdAt.toDate().toLocal()} • Total: ₹${o.total.toStringAsFixed(2)}'),
                  isThreeLine: true,
                  onTap: () {
                    // Navigate to admin order detail route via GoRouter and pass the OrderModel as extra
                    final path = RouteHelper.adminOrderDetail(o.id);
                    try {
                      context.push(path, extra: o);
                    } catch (_) {
                      // Fallback to direct push if go_router isn't available in this context
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailPage(order: o)));
                    }
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val.startsWith('status:')) {
                        final status = val.split(':')[1];
                        context.read<AdminOrderBloc>().add(admin_events.UpdateOrderStatusEvent(o.id, status));
                      } else if (val == 'assign') {
                        _showAssignDialog(context, o.id);
                      } else if (val == 'delete') {
                        context.read<AdminOrderBloc>().add(admin_events.DeleteOrderEvent(o.id));
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'status:pending', child: Text('Mark Pending')),
                      PopupMenuItem(value: 'status:accepted', child: Text('Mark Accepted')),
                      PopupMenuItem(value: 'status:in_progress', child: Text('Mark In Progress')),
                      PopupMenuItem(value: 'status:completed', child: Text('Mark Completed')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'assign', child: Text('Assign Worker')),
                      PopupMenuItem(value: 'delete', child: Text('Delete Order')),
                    ],
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showAssignDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (_) => AssignWorkerDialog(orderId: orderId),
    );
  }
}

class _OrderFilterDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _OrderFilterDialog({this.initial});
  @override
  State<_OrderFilterDialog> createState() => _OrderFilterDialogState();
}

class _OrderFilterDialogState extends State<_OrderFilterDialog> {
  final _userCtrl = TextEditingController();
  final _workerCtrl = TextEditingController();
  final _orderNumberCtrl = TextEditingController();
  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? {};
    _status = init['status'] as String?;
    _userCtrl.text = (init['userId'] ?? init['orderOwner'] ?? '') as String;
    _workerCtrl.text = init['workerId'] as String? ?? '';
    _orderNumberCtrl.text = init['orderNumber'] as String? ?? '';
    _dateFrom = init['dateFrom'] as DateTime?;
    _dateTo = init['dateTo'] as DateTime?;
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _dateFrom ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _dateTo ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _dateTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [null, 'pending', 'accepted', 'assigned', 'in_progress', 'completed', 'cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s ?? 'Any')))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
            ),
            TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: 'User ID (orderOwner)')),
            TextField(controller: _workerCtrl, decoration: const InputDecoration(labelText: 'Worker ID')),
            TextField(controller: _orderNumberCtrl, decoration: const InputDecoration(labelText: 'Order Number')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text(_dateFrom == null ? 'From: any' : 'From: ${DateFormat.yMd().format(_dateFrom!)}')),
              TextButton(onPressed: _pickFrom, child: const Text('Pick')),
            ]),
            Row(children: [
              Expanded(child: Text(_dateTo == null ? 'To: any' : 'To: ${DateFormat.yMd().format(_dateTo!)}')),
              TextButton(onPressed: _pickTo, child: const Text('Pick')),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final Map<String, dynamic> filters = {};
            if (_status != null) filters['status'] = _status;
            if (_userCtrl.text.trim().isNotEmpty) filters['orderOwner'] = _userCtrl.text.trim();
            if (_workerCtrl.text.trim().isNotEmpty) filters['workerId'] = _workerCtrl.text.trim();
            if (_orderNumberCtrl.text.trim().isNotEmpty) filters['orderNumber'] = _orderNumberCtrl.text.trim();
            if (_dateFrom != null) filters['dateFrom'] = _dateFrom;
            if (_dateTo != null) filters['dateTo'] = _dateTo;
            Navigator.pop(context, filters);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
