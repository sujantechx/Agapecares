import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
import 'package:agapecares/core/models/cart_item_model.dart';
import '../bloc/admin_order_bloc.dart';
import '../bloc/admin_order_event.dart' as admin_events;
import 'package:agapecares/features/admin_app/features/worker_management/presentation/widgets/assign_worker_dialog.dart';

class AdminOrderDetailPage extends StatelessWidget {
  final OrderModel order;
  const AdminOrderDetailPage({Key? key, required this.order}) : super(key: key);

  String _formatTs(Timestamp ts) {
    try {
      final dt = ts.toDate();
      return DateFormat.yMd().add_jm().format(dt);
    } catch (_) {
      return ts.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.orderNumber}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(child: Text(order.orderStatus.name.toUpperCase())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${order.id}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),

            // timestamps
            Row(
              children: [
                Expanded(child: Text('Created: ${_formatTs(order.createdAt)}')),
                Expanded(child: Text('Updated: ${_formatTs(order.updatedAt)}')),
              ],
            ),
            const SizedBox(height: 12),

            // User and Worker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('User: ${order.userId}'),
              subtitle: Text('Worker: ${order.workerId ?? 'Unassigned'}'),
            ),

            const Divider(),

            // Items
            Text('Items', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...order.items.map((item) {
              final it = item;
              return ListTile(
                title: Text(it.serviceName.isNotEmpty ? it.serviceName : 'Item'),
                subtitle: Text('Qty: ${it.quantity} • Rs ${it.unitPrice.toStringAsFixed(2)}'),
              );
            }),

            const Divider(),

            // Address
            Text('Service Address', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(order.addressSnapshot.entries.map((e) => '${e.key}: ${e.value}').join('\n')),

            const Divider(),

            // Totals
            Text('Totals', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Subtotal: ₹${order.subtotal.toStringAsFixed(2)}'),
            Text('Discount: ₹${order.discount.toStringAsFixed(2)}'),
            Text('Tax: ₹${order.tax.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text('Total: ₹${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),

            const Divider(),

            // Payment
            Text('Payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Payment Status: ${order.paymentStatus.name}'),
            if (order.paymentRef != null) ...[
              const SizedBox(height: 8),
              Text('Payment Info:'),
              Text(order.paymentRef!.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
            ],

            const Divider(),

            // Assignment History
            Text('Assignment History', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (order.assignmentHistory == null || order.assignmentHistory!.isEmpty)
              const Text('No assignment history')
            else
              ...order.assignmentHistory!.map((h) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h['status']?.toString() ?? ''),
                    subtitle: Text(h['note']?.toString() ?? ''),
                    trailing: Text(h['at'] != null ? h['at'].toString() : ''),
                  )),

            const Divider(),

            // Admin actions
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Assign Worker'),
                  onPressed: () => _showAssignDialog(context),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    // dispatch update status
                    context.read<AdminOrderBloc>().add(admin_events.UpdateOrderStatusEvent(order.id, val));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating status...')));
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                    PopupMenuItem(value: 'accepted', child: Text('Mark Accepted')),
                    PopupMenuItem(value: 'in_progress', child: Text('Mark In Progress')),
                    PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                    PopupMenuItem(value: 'cancelled', child: Text('Mark Cancelled')),
                  ],
                  child: ElevatedButton.icon(icon: const Icon(Icons.edit), label: const Text('Change Status'), onPressed: null),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AssignWorkerDialog(orderId: order.id),
    );
  }
}
