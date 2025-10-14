// Admin order management page
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_bloc.dart';
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_event.dart' as admin_events;
import 'package:agapecares/features/admin_app/features/order_management/presentation/bloc/admin_order_state.dart';

class AdminOrderListPage extends StatelessWidget {
  const AdminOrderListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.read<AdminOrderBloc>().add(admin_events.LoadOrders());
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Orders')),
      body: BlocBuilder<AdminOrderBloc, AdminOrderState>(
        builder: (context, state) {
          if (state is AdminOrderLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminOrderError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is AdminOrderLoaded) {
            if (state.orders.isEmpty) {
              return const Center(child: Text('No orders found'));
            }
            return ListView.builder(
              itemCount: state.orders.length,
              itemBuilder: (context, i) {
                final o = state.orders[i];
                return ListTile(
                  title: Text('#${o.orderNumber} • ${o.orderStatus}'),
                  subtitle: Text('Total: ₹${o.total.toStringAsFixed(2)}\nUser: ${o.userName ?? o.userId}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val.startsWith('status:')) {
                        final status = val.split(':')[1];
                        context.read<AdminOrderBloc>().add(admin_events.UpdateOrderStatusEvent(o.id ?? '', status));
                      } else if (val == 'assign') {
                        _showAssignDialog(context, o.id ?? '');
                      } else if (val == 'delete') {
                        context.read<AdminOrderBloc>().add(admin_events.DeleteOrderEvent(o.id ?? ''));
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
    final workerIdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Worker'),
        content: TextField(
          controller: workerIdCtrl,
          decoration: const InputDecoration(labelText: 'Worker ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final id = workerIdCtrl.text.trim();
              if (id.isNotEmpty) {
                context.read<AdminOrderBloc>().add(admin_events.AssignWorkerEvent(orderId: orderId, workerId: id));
                Navigator.pop(context);
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
