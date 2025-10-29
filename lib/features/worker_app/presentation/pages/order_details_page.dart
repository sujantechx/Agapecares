// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\pages\order_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/order_model.dart';
import '../../logic/blocs/worker_tasks_bloc.dart';
import '../../logic/blocs/worker_tasks_event.dart';
import 'package:intl/intl.dart';

class OrderDetailsPage extends StatelessWidget {
  final OrderModel order;
  const OrderDetailsPage({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheduled = order.scheduledAt.toDate();
    // Show date-only and fixed work hours 09:00 - 18:00 for workers
    final dateStr = DateFormat('dd MMM yyyy').format(scheduled);
    final timeStr = '$dateStr • Work hours: 09:00 - 18:00';
    final addrMap = order.addressSnapshot;
    final addr = (addrMap['address'] as String?) ?? (addrMap['line1'] as String?) ?? '';
    final customerName = (addrMap['name'] as String?) ?? '';
    final customerPhone = (addrMap['phone'] as String?) ?? (addrMap['phoneNumber'] as String?) ?? '';

    final showAccept = order.orderStatus == OrderStatus.pending || order.orderStatus == OrderStatus.assigned;
    final showOnMyWay = order.orderStatus != OrderStatus.completed && order.orderStatus != OrderStatus.on_my_way && order.orderStatus != OrderStatus.arrived;
    final showArrived = order.orderStatus != OrderStatus.completed && order.orderStatus != OrderStatus.arrived && order.orderStatus != OrderStatus.in_progress;
    final showStart = order.orderStatus != OrderStatus.completed && order.orderStatus != OrderStatus.in_progress;
    final showPause = order.orderStatus != OrderStatus.completed;
    final showComplete = order.orderStatus != OrderStatus.completed;

    void updateStatus(OrderStatus s) {
      context.read<WorkerTasksBloc>().add(UpdateOrderStatus(order: order, newStatus: s));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Job • ${order.orderNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.items.isNotEmpty ? order.items.first.serviceName : 'Service', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(timeStr),
            const SizedBox(height: 8),
            Text('Customer: $customerName'),
            Text('Phone: $customerPhone'),
            const SizedBox(height: 8),
            Text('Address:'),
            Text(addr),
            const SizedBox(height: 12),
            Text('Status: ${order.orderStatus.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Payment: ${order.paymentStatus.name}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showAccept)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.accepted), child: const Text('Accept')),
                if (showOnMyWay)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.on_my_way), child: const Text('On My Way')),
                if (showArrived)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.arrived), child: const Text('Arrived')),
                if (showStart)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.in_progress), child: const Text('Started')),
                if (showPause)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.paused), child: const Text('Paused')),
                if (showComplete)
                  ElevatedButton(onPressed: () => updateStatus(OrderStatus.completed), child: const Text('Completed')),
              ],
            ),
            const SizedBox(height: 12),
            if (order.items.isNotEmpty) ...[
              const Text('Inclusions:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.items.map((i) => Text('- ${i.serviceName} • ${i.optionName} x${i.quantity}'))
            ]
          ],
        ),
      ),
    );
  }
}
