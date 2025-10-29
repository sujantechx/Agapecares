import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../../../../../app/routes/app_routes.dart';
import '../../../../../../core/models/order_model.dart';

import 'package:go_router/go_router.dart';

import 'order_details_page.dart';


import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;
import '../../logic/order_bloc.dart';
import '../../logic/order_event.dart';
import '../../logic/order_state.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({Key? key}) : super(key: key);

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late Future<List<OrderModel>> _ordersFuture;
  StreamSubscription<User?>? _authSub;
  bool _hasOrderBloc = false;
  // Guard to ensure we only perform the initial load once. FirebaseAuth.authStateChanges
  // emits the current auth state immediately after subscribing which caused a duplicate
  // load when we also called `_loadOrders()` directly in initState. Use this flag to
  // avoid duplicate back-to-back loads.
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    // Detect if an OrderBloc provider is available. If so we'll use it; otherwise use the Future approach.
    try {
      // read() will throw if provider not found
      final _ = context.read<OrderBloc>();
      _hasOrderBloc = true;
    } catch (_) {
      _hasOrderBloc = false;
    }

    // Subscribe to auth changes and trigger load. Firebase emits the current auth
    // state right away, so this subscription will handle the initial load too.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      debugPrint('[OrderListPage] auth state changed, reloading orders');
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        // First load: call _loadOrders and refresh UI
        _loadOrders();
        if (mounted) setState(() {});
      } else {
        // Subsequent auth changes (login/logout) should also reload
        _loadOrders();
        if (mounted) setState(() {});
      }
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
    if (_hasOrderBloc) {
      try {
        context.read<OrderBloc>().add(LoadOrders(userId));
      } catch (_) {}
    } else {
      _ordersFuture = _loadOrdersFromRepo(userId);
    }
  }

  Future<List<OrderModel>> _loadOrdersFromRepo(String userId) async {
    try {
      final repo = context.read<user_orders_repo.OrderRepository>();
      final fetched = await repo.fetchOrdersForUser(userId);
      debugPrint('[OrderListPage] _loadOrdersFromRepo fetched=${fetched.length} for user=$userId');
      return fetched;
    } catch (e, s) {
      debugPrint('[OrderListPage] _loadOrdersFromRepo failed: $e\n$s');
      // Propagate the error so FutureBuilder can show an error state instead of
      // silently returning an empty list which caused confusion when permissions failed.
      rethrow;
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
      case OrderStatus.on_my_way:
        return Colors.orange.shade500;
      case OrderStatus.arrived:
        return Colors.green.shade600;
      case OrderStatus.in_progress:
        return Colors.orange.shade600;
      case OrderStatus.paused:
        return Colors.amber.shade600;
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
                  // Use GoRouter.of(context).go so we call the extension on the correct BuildContext
                  try {
                    // Prefer GoRouter if available
                    GoRouter.of(context).go(AppRoutes.login);
                  } catch (_) {
                    // Fallback to Navigator if GoRouter isn't wired in this context
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

    // If an OrderBloc is available use it; otherwise fallback to Future-based builder.
    if (_hasOrderBloc) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: RefreshIndicator(
          onRefresh: () async {
            _loadOrders();
            if (mounted) setState(() {});
          },
          child: BlocBuilder<OrderBloc, OrderState>(builder: (context, state) {
            if (state is OrderLoading) return const Center(child: CircularProgressIndicator());
            if (state is OrderError) {
              final msg = state.message ?? 'Failed to load orders';
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 56, color: Colors.red.shade700),
                        const SizedBox(height: 12),
                        Text('Could not load orders', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(msg, textAlign: TextAlign.center, style: const TextStyle()),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Retry using the same load mechanism
                                _loadOrders();
                                if (mounted) setState(() {});
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                // Show guidance — open a dialog with next steps for permissions
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Debug / Next steps'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text('1) Ensure Firestore rules allow reads on top-level `orders` when filtering by orderOwner or userId.'),
                                          SizedBox(height: 8),
                                          Text('2) If you manage rules locally, deploy using `firebase deploy --only firestore:rules`.'),
                                          SizedBox(height: 8),
                                          Text('3) Alternatively, store orders under users/{uid}/orders so regular users can always read their own orders.'),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                                    ],
                                  ),
                                );
                              },
                              child: const Text('Help'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              );
            }
            final orders = (state is OrderLoaded) ? state.orders : <OrderModel>[];
            if (orders.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No orders available', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            _loadOrders();
                            if (mounted) setState(() {});
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final o = orders[index];
                DateTime createdDate = DateTime.now();
                try {
                  final dynamic val = o.createdAt;
                  if (val is DateTime) {
                    createdDate = val;
                  } else if (val is String) {
                    createdDate = DateTime.parse(val);
                  } else if (val is int) {
                    createdDate = DateTime.fromMillisecondsSinceEpoch(val);
                  } else if (val != null) {
                    try {
                      createdDate = (val as dynamic).toDate() as DateTime;
                    } catch (_) {
                      createdDate = DateTime.tryParse(val.toString()) ?? DateTime.now();
                    }
                  }
                } catch (_) {
                  createdDate = DateTime.now();
                }

                final statusColor = _statusColor(o.orderStatus);

                // New, friendlier card-based UI with explicit actions
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Order • ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Flexible(
                                          child: SelectableText(
                                            o.orderNumber.isNotEmpty ? o.orderNumber : (o.id.isNotEmpty ? o.id : '-'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'monospace'),
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18),
                                          tooltip: 'Copy order number',
                                          onPressed: () {
                                            final txt = o.orderNumber.isNotEmpty ? o.orderNumber : (o.id.isNotEmpty ? o.id : '');
                                            if (txt.isNotEmpty) {
                                              Clipboard.setData(ClipboardData(text: txt));
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $txt')));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Placed: ${_formatDateTime(createdDate)}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          const SizedBox(height: 12),
                          // Short summary: service type, address, scheduled date, and assigned worker
                          Text('Service: ${o.items.isNotEmpty ? o.items.first.serviceName : 'Service'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('To: ${(o.addressSnapshot['name'] ?? o.addressSnapshot['address'] ?? 'Address')}', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 6),
                          // scheduled date (defensive)
                          Builder(builder: (ctx) {
                            // Only show scheduled info for assigned orders
                            if (o.orderStatus != OrderStatus.assigned) return const SizedBox.shrink();
                            DateTime? sched;
                            try {
                              final dynamic sval = o.scheduledAt;
                              if (sval is DateTime) sched = sval;
                              else if (sval is String) sched = DateTime.parse(sval);
                              else if (sval is int) sched = DateTime.fromMillisecondsSinceEpoch(sval);
                              else if (sval != null) sched = (sval as dynamic).toDate() as DateTime;
                            } catch (_) {
                              sched = null;
                            }
                            if (sched != null) {
                              final two = (int n) => n.toString().padLeft(2, '0');
                              final s = '${two(sched.day)}-${two(sched.month)}-${sched.year}';
                              return Text('Scheduled: $s • Work hours: 09:00 - 18:00', style: const TextStyle());
                            }
                            return const SizedBox.shrink();
                          }),
                          const SizedBox(height: 6),
                          // Text('Assigned: ${o.workerId != null && o.workerId!.isNotEmpty ? o.workerId! : '—'}', style: const TextStyle()),
                          // const SizedBox(height: 6),
                          Text('Items: ${o.items.length} • Subtotal: ₹${o.subtotal.toStringAsFixed(2)}', style: const TextStyle()),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  // Local 'Check' action: show confirmation and mark visually (no backend change)
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm'),
                                      content: const Text('Mark this order as received/checked?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as checked')));
                                          },
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Check'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  // Navigate to a full details page
                                  try {
                                    GoRouter.of(context).push('/orders/details', extra: o);
                                  } catch (_) {
                                    // Fallback: push named route if available
                                    Navigator.of(context).push(MaterialPageRoute(builder: (c) => OrderDetailsPage(order: o)));
                                  }
                                },
                                child: const Text('View details'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      );
    }

    // Fallback: no OrderBloc -> keep existing FutureBuilder behavior but render as cards
    return Scaffold(
      appBar: AppBar(title: Center(child: const Text('My Orders'))),
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
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No orders available', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            _loadOrders();
                            setState(() {});
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final o = orders[index];
                DateTime createdDate = DateTime.now();
                try {
                  final dynamic val = o.createdAt;
                  if (val is DateTime) {
                    createdDate = val;
                  } else if (val is String) {
                    createdDate = DateTime.parse(val);
                  } else if (val is int) {
                    createdDate = DateTime.fromMillisecondsSinceEpoch(val);
                  } else if (val != null) {
                    try {
                      createdDate = (val as dynamic).toDate() as DateTime;
                    } catch (_) {
                      createdDate = DateTime.tryParse(val.toString()) ?? DateTime.now();
                    }
                  }
                } catch (_) {
                  createdDate = DateTime.now();
                }

                final statusColor = _statusColor(o.orderStatus);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('Order • ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Flexible(
                                          child: SelectableText(
                                            o.orderNumber.isNotEmpty ? o.orderNumber : (o.id.isNotEmpty ? o.id : '-'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                fontFamily: 'monospace'),
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18),
                                          tooltip: 'Copy order number',
                                          onPressed: () {
                                            final txt = o.orderNumber.isNotEmpty ? o.orderNumber : (o.id.isNotEmpty ? o.id : '');
                                            if (txt.isNotEmpty) {
                                              Clipboard.setData(ClipboardData(text: txt));
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $txt')));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Placed: ${_formatDateTime(createdDate)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          const SizedBox(height: 12),
                          // Short summary: service type, address, scheduled date, and assigned worker
                          Text('Service: ${o.items.isNotEmpty ? o.items.first.serviceName : 'Service'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('To: ${(o.addressSnapshot['name'] ?? o.addressSnapshot['address'] ?? 'Address')}', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 6),
                          // scheduled date (defensive)
                          Builder(builder: (ctx) {
                            // Only show scheduled info for assigned orders
                            if (o.orderStatus != OrderStatus.assigned) return const SizedBox.shrink();
                            DateTime? sched;
                            try {
                              final dynamic sval = o.scheduledAt;
                              if (sval is DateTime) sched = sval;
                              else if (sval is String) sched = DateTime.parse(sval);
                              else if (sval is int) sched = DateTime.fromMillisecondsSinceEpoch(sval);
                              else if (sval != null) sched = (sval as dynamic).toDate() as DateTime;
                            } catch (_) {
                              sched = null;
                            }
                            if (sched != null) {
                              final two = (int n) => n.toString().padLeft(2, '0');
                              final s = '${two(sched.day)}-${two(sched.month)}-${sched.year}';
                              return Text('Scheduled: $s • Work hours: 09:00 - 18:00', style: const TextStyle(color: Colors.black54));
                            }
                            return const SizedBox.shrink();
                          }),
                          const SizedBox(height: 6),
                          Text('Assigned: ${o.workerId != null && o.workerId!.isNotEmpty ? o.workerId! : '—'}', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text('Items: ${o.items.length} • Subtotal: ₹${o.subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  // Local 'Check' action: show confirmation and mark visually (no backend change)
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm'),
                                      content: const Text('Mark this order as received/checked?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as checked')));
                                          },
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Check'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  // Navigate to a full details page
                                  try {
                                    GoRouter.of(context).push('/orders/details', extra: o);
                                  } catch (_) {
                                    // Fallback: push named route if available
                                    Navigator.of(context).push(MaterialPageRoute(builder: (c) => OrderDetailsPage(order: o)));
                                  }
                                },
                                child: const Text('View details'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
    }
  }
