import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/order_model.dart';
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

  /// Helper to create a color-coded status chip
  Widget _buildStatusChip(OrderStatus status, BuildContext context) {
    Color color;
    Color onColor;
    String label = status.name.replaceAll('_', ' ').toUpperCase();

    switch (status) {
      case OrderStatus.completed:
        color = Colors.green.shade100;
        onColor = Colors.green.shade900;
        break;
      case OrderStatus.in_progress:
      case OrderStatus.assigned:
      case OrderStatus.on_my_way:
      case OrderStatus.arrived:
        color = Colors.blue.shade100;
        onColor = Colors.blue.shade900;
        break;
      case OrderStatus.cancelled:
        color = Colors.red.shade100;
        onColor = Colors.red.shade900;
        break;
      default:
        color = Colors.orange.shade100;
        onColor = Colors.orange.shade900;
    }
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold, color: onColor),
      backgroundColor: color,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
    );
  }

  /// Helper for section headers
  Widget _buildSectionHeader(String title, BuildContext context,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 16.0, 4.0, 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          order.orderNumber.isNotEmpty ? 'Order #${order.orderNumber}' : 'Order Details',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: _buildStatusChip(order.orderStatus, context)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          // 1. Summary Card
          _buildSummaryCard(context, textTheme),

          // 2. Admin Actions Card
          _buildActionsCard(context),

          // 3. Customer & Worker Card
          _buildCustomerWorkerCard(context, textTheme),

          // 4. Items & Totals Card
          _buildItemsAndTotalsCard(context, textTheme),

          // 5. Address Card
          _buildAddressCard(context, textTheme),

          // 6. Payment Card
          _buildPaymentCard(context, textTheme),

          // 7. Schedule Card
          _buildScheduleCard(context, textTheme),

          // 8. Assignment History Card (Optional)
          _buildAssignmentHistoryCard(context, textTheme),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, TextTheme textTheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order ID'),
              subtitle: SelectableText(order.id, style: textTheme.bodySmall),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.create_outlined),
              title: const Text('Created At'),
              subtitle: Text(_formatTs(order.createdAt)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update_outlined),
              title: const Text('Last Updated'),
              subtitle: Text(_formatTs(order.updatedAt)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            // Status Dropdown
            DropdownButtonFormField<String>(
              value: order.orderStatus.name,
              decoration: const InputDecoration(
                labelText: 'Change Order Status',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
              items: OrderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status.name,
                  child: Text(status.name.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  context
                      .read<AdminOrderBloc>()
                      .add(admin_events.UpdateOrderStatusEvent(order.id, val));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Updating status...')));
                }
              },
            ),
            const SizedBox(height: 12),
            // Assign Worker Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Assign or Re-assign Worker'),
                onPressed: () => _showAssignDialog(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerWorkerCard(BuildContext context, TextTheme textTheme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Customer ID'),
            subtitle: SelectableText(order.userId, style: textTheme.bodySmall),
          ),
          ListTile(
            leading: const Icon(Icons.engineering_outlined),
            title: const Text('Assigned Worker ID'),
            subtitle: SelectableText(
              order.workerId ?? 'Unassigned',
              style: textTheme.bodySmall?.copyWith(
                color: order.workerId == null
                    ? Theme.of(context).colorScheme.error
                    : null,
                fontWeight: order.workerId == null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsAndTotalsCard(BuildContext context, TextTheme textTheme) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Items', style: textTheme.titleMedium),
          ),
          ...order.items.map((item) {
            return ListTile(
              title: Text(item.serviceName.isNotEmpty ? item.serviceName : 'Item'),
              subtitle: Text('Qty: ${item.quantity}'),
              trailing: Text('₹${(item.unitPrice * item.quantity).toStringAsFixed(2)}'),
            );
          }),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Subtotal: ₹${order.subtotal.toStringAsFixed(2)}'),
                Text('Discount: -₹${order.discount.toStringAsFixed(2)}'),
                Text('Tax: ₹${order.tax.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text(
                  'Total: ₹${order.total.toStringAsFixed(2)}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, TextTheme textTheme) {
    // Try to find common address keys
    final name = order.addressSnapshot['name']?.toString();
    final phone = (order.addressSnapshot['phone'] ?? order.addressSnapshot['phoneNumber'])?.toString();
    final address = (order.addressSnapshot['address'] ?? order.addressSnapshot['line1'])?.toString();

    // Fallback for any other data
    final otherDetails = order.addressSnapshot.entries
        .where((e) => e.key != 'name' && e.key != 'phone' && e.key != 'phoneNumber' && e.key != 'address' && e.key != 'line1')
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_outlined),
        title: Text(name ?? 'Service Address'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone != null) Text(phone),
            if (address != null) Text(address),
            if (otherDetails.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(otherDetails, style: textTheme.bodySmall),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, TextTheme textTheme) {
    final paymentId = order.paymentRef?['id']?.toString() ??
        order.paymentRef?['payment_id']?.toString();
    final method = order.paymentRef?['method']?.toString();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              order.paymentStatus.name.toLowerCase() == 'completed'
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              color: order.paymentStatus.name.toLowerCase() == 'completed'
                  ? Colors.green
                  : Colors.orange,
            ),
            title: const Text('Payment Status'),
            trailing: Text(
              order.paymentStatus.name.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (paymentId != null || method != null) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.credit_card_outlined),
              title: const Text('Payment Details'),
              subtitle: Text(
                'Method: ${method ?? 'N/A'}\nRef: ${paymentId ?? 'N/A'}',
                style: textTheme.bodySmall,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, TextTheme textTheme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Scheduled At'),
            subtitle: Text(_formatTs(order.scheduledAt)),
          ),
          if (order.appointmentId != null)
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Appointment ID'),
              subtitle: SelectableText(order.appointmentId!, style: textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _buildAssignmentHistoryCard(BuildContext context, TextTheme textTheme) {
    if (order.assignmentHistory == null || order.assignmentHistory!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.history_outlined),
        title: const Text('Assignment History'),
        children: order.assignmentHistory!.map((h) {
          final status = h['status']?.toString() ?? 'N/A';
          final note = h['note']?.toString() ?? 'No note';
          final time = (h['at'] is Timestamp) ? _formatTs(h['at']) : 'Invalid date';

          return ListTile(
            title: Text(status.toUpperCase()),
            subtitle: Text(note),
            trailing: Text(time, style: textTheme.bodySmall),
          );
        }).toList(),
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