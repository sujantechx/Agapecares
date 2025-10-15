import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/models/order_model.dart';

import 'package:flutter/services.dart';

import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({Key? key}) : super(key: key);

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late Future<List<OrderModel>> _ordersFuture;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Reload orders when auth changes (login/logout) so UI updates automatically
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      debugPrint('[OrderListPage] auth state changed, reloading orders');
      _loadOrders();
      if (mounted) setState(() {});
    });
  }

  void _loadOrders() {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Prefer UID (stable) over phone number to match how orders are uploaded.
    final userId = currentUser?.uid ?? currentUser?.phoneNumber;
    debugPrint('[OrderListPage] _loadOrders currentUser=${currentUser?.uid ?? currentUser?.phoneNumber}');
    if (userId == null) {
      _ordersFuture = Future.value([]);
      return;
    }
    _ordersFuture = _loadOrdersFromRepo(userId);
  }

  Future<List<OrderModel>> _loadOrdersFromRepo(String userId) async {
    final repo = context.read<OrderRepository>();
    try {
      final merged = await repo.getAllOrdersForUser(userId);
      debugPrint('[OrderListPage] _loadOrdersFromRepo mergedCount=${merged.length}');
      if (merged.isNotEmpty) return merged;

      return merged;
    } catch (e, s) {
      debugPrint('[OrderListPage] _loadOrdersFromRepo failed: $e\n$s');
      return <OrderModel>[];
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.blueGrey.shade600;
      case OrderStatus.accepted:
      case OrderStatus.assigned:
        return Colors.orange.shade700;
      case OrderStatus.in_progress:
        return Colors.orange.shade600;
      case OrderStatus.completed:
        return Colors.green.shade700;
      case OrderStatus.cancelled:
        return Colors.red.shade600;
    }
  }

  String _orderStatusLabel(OrderStatus status) => status.name.replaceAll('_', ' ').toUpperCase();

  String _paymentStatusLabel(PaymentStatus status) => status.name.toUpperCase();
  Color _paymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.blueGrey.shade600;
      case PaymentStatus.paid:
        return Colors.green.shade600;
      case PaymentStatus.failed:
        return Colors.red.shade600;
      case PaymentStatus.refunded:
        return Colors.orange.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You are not logged in.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login - use centralized route constant and GoRouter
                  // ignore: deprecated_member_use_from_same_package
                  // Using context.go from go_router package
                  // Replace at runtime
                  final go = (context as dynamic).go as void Function(String);
                  try {
                    go(AppRoutes.login);
                  } catch (_) {
                    // Fallback: pushNamed if go_router not available at runtime
                    Navigator.of(context).pushNamed(AppRoutes.login);
                  }
                },
                child: const Text('Login'),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadOrders();
          setState(() {});
          await _ordersFuture;
        },
        child: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load orders: ${snap.error}'),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () { _loadOrders(); setState(() {}); }, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No orders yet')),
                ],
              );
            }

            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final o = orders[index];
                final created = o.createdAt;
                // created may be a Timestamp from Firestore, a DateTime, or an ISO string; convert defensively
                DateTime createdDate;
                try {
                  final dynamic val = created;
                  if (val is DateTime) {
                    createdDate = val;
                  } else if (val is String) {
                    createdDate = DateTime.parse(val);
                  } else if (val is int) {
                    createdDate = DateTime.fromMillisecondsSinceEpoch(val);
                  } else if (val != null) {
                    // Firestore Timestamp or other object with toDate()
                    try {
                      createdDate = (val as dynamic).toDate() as DateTime;
                    } catch (_) {
                      createdDate = DateTime.tryParse(val.toString()) ?? DateTime.now();
                    }
                  } else {
                    createdDate = DateTime.now();
                  }
                } catch (_) {
                  createdDate = DateTime.now();
                }

                // Use _orderStatusLabel (existing helper) and _statusColor for display
                final statusColor = _statusColor(o.orderStatus);

                return ExpansionTile(
                  key: ValueKey(o.id.isNotEmpty ? o.id : index),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order • ${o.orderNumber.isNotEmpty ? o.orderNumber : (o.id.isNotEmpty ? o.id : '-')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Placed: ${_formatDateTime(createdDate)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Chip(
                                label: Text(_orderStatusLabel(o.orderStatus), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                backgroundColor: statusColor,
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(_paymentStatusLabel(o.paymentStatus), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                backgroundColor: _paymentStatusColor(o.paymentStatus),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Show userId (uid) as identifier and fallback
                              Text(o.userId.isNotEmpty ? o.userId : 'Unknown User', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(_paymentStatusLabel(o.paymentStatus), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Address snapshot
                          const SizedBox(height: 6),
                          Text('Address: ${o.addressSnapshot['address'] ?? 'Not provided'}', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 8),
                          // payment id not stored on OrderModel by default
                          const Divider(),
                          const SizedBox(height: 6),
                          const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ...o.items.map((it) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('${it.serviceName} × ${it.quantity}', style: const TextStyle(fontSize: 14))),
                                    Text('₹${(it.unitPrice * it.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Subtotal: ₹${o.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 12),
                              Text('Total: ₹${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Rating not available on current OrderModel; remove rating UI
                        ],
                      ),
                    )
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
