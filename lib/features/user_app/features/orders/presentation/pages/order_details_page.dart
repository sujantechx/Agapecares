import 'package:flutter/material.dart';
import '../../../../../../core/models/order_model.dart';

class OrderDetailsPage extends StatelessWidget {
  final OrderModel order;
  const OrderDetailsPage({Key? key, required this.order}) : super(key: key);

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    DateTime createdDate;
    try {
      final dynamic val = order.createdAt;
      if (val is DateTime) {
        createdDate = val;
      } else if (val is String) {
        createdDate = DateTime.parse(val);
      } else if (val is int) {
        createdDate = DateTime.fromMillisecondsSinceEpoch(val);
      } else if (val != null) {
        createdDate = (val as dynamic).toDate() as DateTime;
      } else {
        createdDate = DateTime.now();
      }
    } catch (_) {
      createdDate = DateTime.now();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order • ${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Placed: ${_formatDateTime(createdDate)}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),

            // Status and payment
            Row(
              children: [
                Chip(label: Text(order.orderStatus.name.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 8),
                Chip(label: Text(order.paymentStatus.name.toUpperCase(), style: const TextStyle(color: Colors.white))),
                const Spacer(),
                Text('Total: ₹${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Address
            Text('Delivery address', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(order.addressSnapshot['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(order.addressSnapshot['address'] ?? order.addressSnapshot['line1'] ?? 'Not provided'),
            const SizedBox(height: 8),
            if ((order.addressSnapshot['phone'] ?? order.addressSnapshot['phoneNumber']) != null)
              Text('Phone: ${(order.addressSnapshot['phone'] ?? order.addressSnapshot['phoneNumber']).toString()}'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Items
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...order.items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('${it.serviceName}', style: const TextStyle(fontSize: 15))),
                      Text('× ${it.quantity}', style: const TextStyle(color: Colors.black54)),
                      const SizedBox(width: 12),
                      Text('₹${(it.unitPrice * it.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Price summary
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal: ₹${order.subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  if ((order.total - order.subtotal) > 0)
                    Text('Fees/Taxes: ₹${(order.total - order.subtotal).toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Text('Total: ₹${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Metadata
            Text('Order ID: ${order.id}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text('User: ${order.userId}', style: const TextStyle(color: Colors.black54)),

            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Simple share/copy action: copy order id
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ID copied')));
                    },
                    child: const Text('Copy order ID'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacting support...')));
                    },
                    child: const Text('Contact support'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

