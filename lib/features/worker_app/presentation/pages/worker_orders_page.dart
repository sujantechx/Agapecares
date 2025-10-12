import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agapecares/features/user_app/data/repositories/order_repository.dart';
import 'package:agapecares/shared/models/order_model.dart';
import 'package:provider/provider.dart';
import 'package:agapecares/shared/services/session_service.dart';

class WorkerOrdersPage extends StatefulWidget {
  const WorkerOrdersPage({Key? key}) : super(key: key);

  @override
  State<WorkerOrdersPage> createState() => _WorkerOrdersPageState();
}

class _WorkerOrdersPageState extends State<WorkerOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late OrderRepository _orderRepo;
  String? _workerId;
  String? _workerName;

  List<OrderModel> _incoming = [];
  List<OrderModel> _assigned = [];
  List<OrderModel> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndLoad());
  }

  Future<void> _initAndLoad() async {
    _orderRepo = context.read<OrderRepository>();
    // Derive worker id/name from SessionService or FirebaseAuth
    try {
      final session = context.read<SessionService>();
      final user = session.getUser();
      if (user != null && user.role == 'worker' && user.uid.isNotEmpty) {
        _workerId = user.uid;
        _workerName = user.name ?? '';
      }
    } catch (_) {}
    final fb = FirebaseAuth.instance.currentUser;
    if ((_workerId == null || _workerId!.isEmpty) && fb != null) {
      _workerId = fb.uid;
      _workerName = fb.displayName ?? _workerName ?? '';
    }
    await _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadIncoming();
    await _loadAssigned();
    await _loadHistory();
    setState(() => _loading = false);
  }

  Future<void> _loadIncoming() async {
    try {
      final list = await _orderRepo.getIncomingOrdersForWorker(withinHours: 1);
      setState(() => _incoming = list);
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadIncoming error: $e');
    }
  }

  Future<void> _loadAssigned() async {
    if (_workerId == null) return;
    try {
      final list = await _orderRepo.getAssignedOrdersForWorker(_workerId!);
      setState(() => _assigned = list.where((o) => o.orderStatus.toLowerCase() != 'completed').toList());
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadAssigned error: $e');
    }
  }

  Future<void> _loadHistory() async {
    if (_workerId == null) return;
    try {
      final list = await _orderRepo.getAssignedOrdersForWorker(_workerId!);
      setState(() => _history = list.where((o) => o.orderStatus.toLowerCase() == 'completed').toList());
    } catch (e) {
      debugPrint('[WorkerOrdersPage] loadHistory error: $e');
    }
  }

  Future<void> _acceptOrder(OrderModel order) async {
    if (_workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker id not found')));
      return;
    }
    final ok = await _orderRepo.assignOrderToWorker(order: order, workerId: _workerId!, workerName: _workerName ?? '');
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted')));
      await _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to accept order')));
    }
  }

  Future<void> _completeOrder(OrderModel order) async {
    final ok = await _orderRepo.completeOrder(order);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked completed')));
      await _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to complete order')));
    }
  }

  Widget _buildOrderTile(OrderModel o, {bool showAccept = false, bool showComplete = false}) {
    final created = o.createdAt;
    DateTime createdDate;
    try {
      createdDate = (created as dynamic).toDate() as DateTime;
    } catch (_) {
      createdDate = DateTime.now();
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order • ${o.orderNumber.isNotEmpty ? o.orderNumber : (o.id ?? 'Local:${o.localId ?? '-'}')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${o.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Placed: ${createdDate.toLocal()}'),
            const SizedBox(height: 6),
            Text('User: ${o.userName} • ${o.userPhone}'),
            const SizedBox(height: 6),
            Text('Address: ${o.userAddress}'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text('Items:', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...o.items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${it.service.name} × ${it.quantity}')),
                      Text('₹${(it.price * it.quantity).toStringAsFixed(2)}'),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showAccept)
                  ElevatedButton(
                    onPressed: () => _acceptOrder(o),
                    child: const Text('Accept'),
                  ),
                if (showComplete)
                  ElevatedButton(
                    onPressed: () => _completeOrder(o),
                    child: const Text('Mark Complete'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Incoming'), Tab(text: 'Assigned'), Tab(text: 'History')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadIncoming,
                  child: _incoming.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No incoming orders'))])
                      : ListView.builder(
                          itemCount: _incoming.length,
                          itemBuilder: (context, i) => _buildOrderTile(_incoming[i], showAccept: true),
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _loadAssigned,
                  child: _assigned.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No assigned orders'))])
                      : ListView.builder(
                          itemCount: _assigned.length,
                          itemBuilder: (context, i) => _buildOrderTile(_assigned[i], showComplete: true),
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: _history.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No history'))])
                      : ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, i) => _buildOrderTile(_history[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

