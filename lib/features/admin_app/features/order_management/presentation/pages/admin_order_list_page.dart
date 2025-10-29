// Admin order management page
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart'
as admin_events;
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_state.dart';
import 'package:intl/intl.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/pages/admin_order_detail_page.dart';
import 'package:agapecares/app/routes/route_helpers.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/features/admin_app/features/worker_management/presentation/widgets/assign_worker_dialog.dart';

// Assuming OrderModel is imported from your project
import 'package:agapecares/core/models/order_model.dart';

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
    context
        .read<AdminOrderBloc>()
        .add(admin_events.LoadOrders(filters: _filters));
  }

  void _openFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OrderFilterDialog(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      context
          .read<AdminOrderBloc>()
          .add(admin_events.LoadOrders(filters: _filters));
    }
  }

  void _showAssignDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (_) => AssignWorkerDialog(orderId: orderId),
    );
  }

  void _confirmDelete(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to permanently delete this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              context
                  .read<AdminOrderBloc>()
                  .add(admin_events.DeleteOrderEvent(orderId));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Orders'),
        actions: [
          IconButton(
            onPressed: _openFilterDialog,
            icon: Badge(
              // Show a dot if filters are active
              isLabelVisible: _filters != null && _filters!.isNotEmpty,
              child: const Icon(Icons.filter_list),
            ),
          ),
          IconButton(
            onPressed: () => context
                .read<AdminOrderBloc>()
                .add(admin_events.LoadOrders(filters: _filters)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<AdminOrderBloc, AdminOrderState>(
        builder: (context, state) {
          if (state is AdminOrderLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminOrderError) {
            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12.0),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.error,
                            color: Theme.of(context).colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Admin fetch error: ${state.message}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Error: ${state.message}'),
                  ),
                ),
              ],
            );
          }

          if (state is AdminOrderLoaded) {
            if (state.orders.isEmpty) {
              return const Center(child: Text('No orders found'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: state.orders.length,
              itemBuilder: (context, i) {
                final o = state.orders[i];
                return _buildOrderCard(context, o);
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Extracts the order item UI into a clean, modern Card
  Widget _buildOrderCard(BuildContext context, OrderModel o) {
    final textTheme = Theme.of(context).textTheme;
    final formattedDate =
    DateFormat.yMd().add_jm().format(o.createdAt.toDate().toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable Header for navigation
          ListTile(
            leading: CircleAvatar(
              child: const Icon(Icons.receipt_long_outlined),
            ),
            title: Text(
              o.orderNumber.isNotEmpty ? o.orderNumber : o.id,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Total: ₹${o.total.toStringAsFixed(2)}',
              style: textTheme.bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final path = RouteHelper.adminOrderDetail(o.id);
              try {
                context.push(path, extra: o);
              } catch (_) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AdminOrderDetailPage(order: o)));
              }
            },
          ),
          // Details section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusChip(o.orderStatus),
                const SizedBox(height: 8),
                Text('User: ${o.userId}', style: textTheme.bodyMedium),
                Text('Placed: $formattedDate', style: textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Assign Worker Button
                TextButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Assign'),
                  onPressed: () => _showAssignDialog(context, o.id),
                ),
                // Delete Button
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () => _confirmDelete(context, o.id),
                  tooltip: 'Delete Order',
                ),
                // Status Dropdown
                _buildStatusDropdown(context, o),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a Dropdown for updating status
  Widget _buildStatusDropdown(BuildContext context, OrderModel o) {
    // Get all enum values as strings
    final statuses =
    OrderStatus.values.map((s) => s.name).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade400, width: 1.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: o.orderStatus.name,
          items: statuses.map((String status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            );
          }).toList(),
          onChanged: (String? newStatus) {
            if (newStatus != null && newStatus != o.orderStatus.name) {
              context
                  .read<AdminOrderBloc>()
                  .add(admin_events.UpdateOrderStatusEvent(o.id, newStatus));
            }
          },
        ),
      ),
    );
  }

  /// Helper to create a color-coded status chip
  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    String label = status.name.replaceAll('_', ' ').toUpperCase();
    switch (status) {
      case OrderStatus.completed:
        color = Colors.green.shade100;
        break;
      case OrderStatus.in_progress:
      case OrderStatus.assigned:
      case OrderStatus.on_my_way:
      case OrderStatus.arrived:
        color = Colors.blue.shade100;
        break;
      case OrderStatus.cancelled:
        color = Colors.red.shade100;
        break;
      case OrderStatus.pending:
      case OrderStatus.accepted:
      default:
        color = Colors.orange.shade100;
    }
    return Chip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      side: BorderSide.none,
    );
  }
}

/// A modern, user-friendly filter dialog
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
    _applyFilters(widget.initial);
  }

  void _applyFilters(Map<String, dynamic>? filters) {
    final init = filters ?? {};
    _status = init['status'] as String?;
    _userCtrl.text = (init['userId'] ?? init['orderOwner'] ?? '') as String;
    _workerCtrl.text = init['workerId'] as String? ?? '';
    _orderNumberCtrl.text = init['orderNumber'] as String? ?? '';
    _dateFrom = init['dateFrom'] as DateTime?;
    _dateTo = init['dateTo'] as DateTime?;
  }

  void _clearFilters() {
    setState(() {
      _status = null;
      _userCtrl.clear();
      _workerCtrl.clear();
      _orderNumberCtrl.clear();
      _dateFrom = null;
      _dateTo = null;
    });
    // Pop with empty map to clear
    Navigator.pop(context, <String, dynamic>{});
  }

  void _submitFilters() {
    final Map<String, dynamic> filters = {};
    if (_status != null) filters['status'] = _status;
    if (_userCtrl.text.trim().isNotEmpty) {
      filters['orderOwner'] = _userCtrl.text.trim();
    }
    if (_workerCtrl.text.trim().isNotEmpty) {
      filters['workerId'] = _workerCtrl.text.trim();
    }
    if (_orderNumberCtrl.text.trim().isNotEmpty) {
      filters['orderNumber'] = _orderNumberCtrl.text.trim();
    }
    if (_dateFrom != null) filters['dateFrom'] = _dateFrom;
    if (_dateTo != null) filters['dateTo'] = _dateTo;
    Navigator.pop(context, filters);
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: _dateFrom ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: _dateTo ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100));
    if (picked != null) setState(() => _dateTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    const fieldDecoration = InputDecoration(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
    const spacing = SizedBox(height: 16);

    return AlertDialog(
      title: const Text('Filter Orders'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _status,
              decoration: fieldDecoration.copyWith(labelText: 'Status'),
              items: [
                null,
                'pending',
                'accepted',
                'assigned',
                'in_progress',
                'completed',
                'cancelled'
              ]
                  .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s ?? 'Any Status')))
                  .toList(),
              onChanged: (v) => setState(() => _status = v),
            ),
            spacing,
            TextFormField(
                controller: _userCtrl,
                decoration:
                fieldDecoration.copyWith(labelText: 'User ID (orderOwner)')),
            spacing,
            TextFormField(
                controller: _workerCtrl,
                decoration: fieldDecoration.copyWith(labelText: 'Worker ID')),
            spacing,
            TextFormField(
                controller: _orderNumberCtrl,
                decoration: fieldDecoration.copyWith(labelText: 'Order Number')),
            spacing,
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('From Date'),
              subtitle: Text(
                  _dateFrom == null ? 'Any' : DateFormat.yMd().format(_dateFrom!)),
              onTap: _pickFrom,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('To Date'),
              subtitle: Text(
                  _dateTo == null ? 'Any' : DateFormat.yMd().format(_dateTo!)),
              onTap: _pickTo,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _clearFilters, child: const Text('Clear')),
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitFilters,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}