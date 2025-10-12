import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/user_app/data/repositories/order_repository.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/services/local_database_service.dart';

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

      // If remote returned empty, also try local unsynced orders (covers COD or offline orders)
      try {
        final localDb = context.read<LocalDatabaseService>();
        final localUnsynced = await localDb.getUnsyncedOrders();
        debugPrint('[OrderListPage] localUnsynced count=${localUnsynced.length}');
        final fbUser = FirebaseAuth.instance.currentUser;
        final localForUser = localUnsynced.where((o) {
          final oUser = (o.userId).trim();
          if (oUser.isNotEmpty && oUser == userId) return true;
          if (oUser.isEmpty && fbUser != null) {
            final uid = fbUser.uid.trim();
            final phone = fbUser.phoneNumber?.trim();
            if ((uid.isNotEmpty && uid == userId) || (phone != null && phone == userId)) return true;
          }
          return false;
        }).toList();
        if (localForUser.isNotEmpty) return localForUser;
      } catch (e, s) {
        debugPrint('[OrderListPage] failed to read local unsynced orders: $e\n$s');
      }

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

  Color _statusColor(String status, String paymentMethod) {
    final s = status.toLowerCase();
    if (s.contains('success')) return Colors.green.shade600;
    if (s.contains('fail')) return Colors.red.shade600;
    if (paymentMethod.toLowerCase() == 'cod') return Colors.orange.shade700;
    return Colors.blueGrey.shade600; // pending/placed
  }

  String _statusLabel(String status, String paymentMethod) {
    final s = status.toLowerCase();
    if (s.contains('success')) return 'Success';
    if (s.contains('fail')) return 'Failed';
    if (paymentMethod.toLowerCase() == 'cod') return 'COD (Pending)';
    return 'Pending';
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
                  // Navigate to login - keep it simple and use route constant if available
                  Navigator.of(context).pushNamed('/login');
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
                // created may be a Timestamp from Firestore; convert defensively
                DateTime createdDate;
                try {
                  createdDate = (created as dynamic).toDate() as DateTime;
                } catch (_) {
                  createdDate = DateTime.now();
                }

                final statusLabel = _statusLabel(o.orderStatus, o.paymentMethod);
                final statusColor = _statusColor(o.orderStatus, o.paymentMethod);

                return ExpansionTile(
                  key: ValueKey(o.id ?? o.localId ?? index),
                  title: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order • ${o.orderNumber.isNotEmpty ? o.orderNumber : (o.id ?? 'Local:${o.localId ?? "-"}')}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          Chip(
                            label: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: statusColor,
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
                              Text(o.userName.isNotEmpty ? o.userName : 'Name not provided', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(o.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Phone: ${o.userPhone}', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('Address: ${o.userAddress}', style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 8),
                          if (o.paymentId != null && (o.paymentId ?? '').isNotEmpty) ...[
                            Text('Payment id: ${o.paymentId}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            const SizedBox(height: 8),
                          ],
                          const Divider(),
                          const SizedBox(height: 6),
                          const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ...o.items.map((it) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('${it.service.name} × ${it.quantity}', style: const TextStyle(fontSize: 14))),
                                    Text('₹${(it.price * it.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
