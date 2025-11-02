// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\widgets\order_list_tile.dart

import 'package:flutter/material.dart';
import '../../../../core/models/order_model.dart';
import 'package:intl/intl.dart';

class OrderListTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderListTile({Key? key, required this.order, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheduled = order.scheduledAt.toDate();
    final timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(scheduled);

    // Robust extraction: check many common snapshot keys then fall back to top-level fields
    String extractAddress(Map<String, dynamic>? snap, Map<String, dynamic> top) {
      if (snap != null) {
        final keys = ['address', 'line1', 'line_1', 'formatted', 'formattedAddress', 'formatted_address', 'fullAddress', 'street', 'streetAddress', 'displayAddress'];
        for (final k in keys) {
          final v = snap[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
      final topKeys = ['address', 'line1', 'formattedAddress', 'formatted_address', 'fullAddress', 'addressLine', 'streetAddress', 'displayAddress'];
      for (final k in topKeys) {
        final v = top[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return 'Address';
    }

    final addr = extractAddress(order.addressSnapshot, {});
    final customerName = (order.addressSnapshot['name'] as String?) ?? order.userName ?? order.userId;
    final customerPhone = (order.addressSnapshot['phone'] as String?) ?? (order.addressSnapshot['phoneNumber'] as String?) ?? order.userPhone ?? '';

    final isCod = order.paymentStatus == PaymentStatus.pending && (order.paymentRef == null || order.paymentRef!.isEmpty);

    return ListTile(
      onTap: onTap,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(order.items.isNotEmpty ? order.items.first.serviceName : 'Service'),
        if (order.orderNumber.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('#${order.orderNumber}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]
      ]),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeStr),
          const SizedBox(height: 4),
          Text('$addr'),
          const SizedBox(height: 4),
          Text('$customerName • $customerPhone'),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCod)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
              child: const Text('COD', style: TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 8),
          Text(order.orderStatus.name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
