import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../../../core/models/order_model.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart'
as user_orders_repo;

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;
  const OrderDetailsPage({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  double? _selectedRating;
  double? _selectedWorkerRating;
  bool _isSubmitting = false;
  bool _isEditingRating = false;
  final TextEditingController _reviewController = TextEditingController();
  late OrderModel _order;
  String? _workerName;
  String? _workerPhone;

  // --- Date Formatting (Unchanged) ---
  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _formatDateOnly(DateTime dt) {
    final d = dt.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year}';
  }

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.order.serviceRating;
    _selectedWorkerRating = widget.order.workerRating;
    _order = widget.order;
    if (_order.workerId != null && _order.workerId!.isNotEmpty) {
      _loadWorkerProfile(_order.workerId!);
    }
  }

  // --- All Logic Methods (Unchanged) ---
  // _prefillExistingReview, dispose, _submitRating,
  // _buildStarRating, _buildWorkerStarRating, _loadWorkerProfile

  Future<void> _prefillExistingReview() async {
    try {
      final cg = FirebaseFirestore.instance
          .collectionGroup('ratings')
          .where('orderId', isEqualTo: _order.id)
          .where('userId', isEqualTo: _order.userId)
          .limit(1);
      final snap = await cg.get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        final comment =
            (d['review'] as String?) ?? (d['comment'] as String?) ?? '';
        final ratingVal = (d['rating'] as num?)?.toDouble();
        setState(() {
          _reviewController.text = comment;
          if (ratingVal != null) _selectedRating = ratingVal;
        });
      } else {
        setState(() {
          _reviewController.text = '';
        });
      }
    } catch (e) {
      debugPrint('[OrderDetailsPage] _prefillExistingReview failed: $e');
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) return;
    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<user_orders_repo.OrderRepository>();
      final success = await repo.submitRatingForOrder(
          order: _order,
          serviceRating: _selectedRating!,
          workerRating: _selectedWorkerRating,
          review: _reviewController.text.trim());
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks! Your rating has been submitted.')));
        setState(() {
          _order = _order.copyWith(
              serviceRating: _selectedRating,
              workerRating: _selectedWorkerRating);
          _isEditingRating = false; // Exit edit mode
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit rating. Try again.')));
      }
    } catch (e) {
      String msg = 'Error submitting rating. Please try again.';
      if (e is FirebaseFunctionsException) {
        if (e.code == 'not-found') {
          msg = 'Rating service not available. Please deploy Cloud Functions.';
        } else if (e.code == 'permission-denied') {
          msg = 'Permission denied while submitting rating.';
        } else if (e.code == 'already-exists') {
          msg = 'This order already has a rating.';
        } else if (e.message != null && e.message!.isNotEmpty) {
          msg = 'Rating failed: ${e.message}';
        }
      } else if (e is Exception) {
        msg = 'Error submitting rating: ${e.toString()}';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStarRating() {
    final current = _selectedRating ?? 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = current >= starIndex;
        return IconButton(
          iconSize: 32,
          icon: Icon(filled ? Icons.star : Icons.star_border,
              color: Colors.amber),
          onPressed: () {
            setState(() => _selectedRating = starIndex.toDouble());
          },
        );
      }),
    );
  }

  Widget _buildWorkerStarRating() {
    final current = _selectedWorkerRating ?? 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = current >= starIndex;
        return IconButton(
          iconSize: 32,
          icon: Icon(filled ? Icons.person : Icons.person_outline,
              color: Colors.amber),
          onPressed: () {
            setState(() => _selectedWorkerRating = starIndex.toDouble());
          },
        );
      }),
    );
  }

  Future<void> _loadWorkerProfile(String workerId) async {
    try {
      final wdoc =
      await FirebaseFirestore.instance.collection('workers').doc(workerId).get();
      if (wdoc.exists) {
        final wdata = wdoc.data() ?? {};
        setState(() {
          _workerName = (wdata['name'] as String?) ??
              (wdata['workerName'] as String?) ??
              'Worker';
          _workerPhone = (wdata['phoneNumber'] as String?) ??
              (wdata['phone'] as String?) ??
              '';
        });
        return;
      }
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(workerId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        setState(() {
          _workerName = (data['name'] as String?) ??
              (data['displayName'] as String?) ??
              'Worker';
          _workerPhone = (data['phoneNumber'] as String?) ??
              (data['phone'] as String?) ??
              '';
        });
      }
    } catch (e) {
      debugPrint('[OrderDetailsPage] _loadWorkerProfile failed: $e');
    }
  }

  // --- NEW: UI Helper Widgets ---

  /// Builds a standard section header
  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Groups statuses for the timeline
  OrderStatus _getCanonicalStatus(OrderStatus status) {
    // Keep canonicalization simple for now — no grouping so each status gets its own step.
    return status;
  }

  /// Gets the current step index for the timeline
  int _getStepIndex(OrderStatus status) {
    final canonicalStatus = _getCanonicalStatus(status);
    switch (canonicalStatus) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.assigned:
        return 1;
      case OrderStatus.on_my_way:
        return 2;
      case OrderStatus.arrived:
        return 3;
      case OrderStatus.in_progress:
        return 4;
      case OrderStatus.completed:
        return 5;
      default:
        if (status == OrderStatus.cancelled) return -1; // Cancelled
        return 0;
    }
  }

  /// **NEW:** Builds the order status timeline
  Widget _buildStatusTimeline(OrderStatus currentStatus) {
    final int currentStep = _getStepIndex(currentStatus);
    if (currentStep == -1) {
      // Special case for cancelled orders
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red[700]),
              const SizedBox(width: 12),
              Text(
                'Order Cancelled',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      );
    }

    final statuses = [
      'Pending',
      'Assigned',
      'On Way',
      'Arrived',
      'In Progress',
      'Completed'
    ];
    final icons = [
      Icons.schedule, // Pending
      Icons.person_pin, // Assigned
      Icons.directions_bike_outlined, // On Way (vehicle)
      Icons.location_on, // Arrived
      Icons.hourglass_bottom, // In Progress (changed icon)
      Icons.check_circle // Completed
    ];

    // Build a list of widgets: step, divider, step, divider, ...
    final List<Widget> children = [];
    for (var i = 0; i < statuses.length; i++) {
      final bool isActive = i == currentStep;
      final bool isCompleted = i < currentStep;
      final color = isCompleted || isActive
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[400];

      children.add(
        Expanded(
          child: Column(
            children: [
              Icon(icons[i], color: color),
              const SizedBox(height: 4),
              Text(
                statuses[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Add divider between steps
      if (i < statuses.length - 1) {
        children.add(
          SizedBox(
            width: 24,
            child: Center(
              child: Container(
                height: 2,
                color: i < currentStep ? Theme.of(context).colorScheme.primary : Colors.grey[300],
              ),
            ),
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
        child: Row(children: children),
      ),
    );
  }
  /// **NEW:** Builds the main summary card
  Widget _buildSummaryCard(
      OrderModel order, DateTime createdDate, ThemeData theme) {
    final orderId = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
    return Card(
      elevation: 2.0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Order ID:',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        orderId,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: orderId));
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied: $orderId')));
                      },
                      child: Icon(Icons.copy,
                          size: 18, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Total: ',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${order.total.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Placed: ${_formatDateTime(createdDate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              order.paymentStatus == PaymentStatus.paid
                  ? Icons.check_circle
                  : Icons.pending,
              color: order.paymentStatus == PaymentStatus.paid
                  ? Colors.green
                  : Colors.orange,
            ),
            title: const Text('Payment Status'),
            trailing: Text(
              order.paymentStatus.name.toUpperCase(),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// **NEW:** Builds the delivery and items card
  Widget _buildDeliveryItemsCard(
      OrderModel order, DateTime? scheduledDate, ThemeData theme) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Address', style: theme.textTheme.titleMedium),
                // const SizedBox(height: 8),
                Text(
                  order.addressSnapshot['name'] ?? '',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                // const SizedBox(height: 4),
                Text(
                  order.addressSnapshot['address'] ??
                      order.addressSnapshot['line1'] ??
                      'Not provided',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if ((order.addressSnapshot['phone'] ??
                    order.addressSnapshot['phoneNumber']) !=
                    null)
                  Text(
                    'Phone: ${(order.addressSnapshot['phone'] ?? order.addressSnapshot['phoneNumber']).toString()}',
                    style: theme.textTheme.bodyMedium,
                  ),
                if (scheduledDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Scheduled: ${_formatDateOnly(scheduledDate)} (09:00 - 18:00)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Items', style: theme.textTheme.titleMedium),
          ),
          ...order.items.map((it) => ListTile(
            title: Text(it.serviceName),
            subtitle: Text('Qty: ${it.quantity}'),
            trailing: Text(
              '₹${(it.unitPrice * it.quantity).toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          )),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal: ₹${order.subtotal.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall),
                  if ((order.total - order.subtotal) > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                        'Fees/Taxes: ₹${(order.total - order.subtotal).toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 8),
                  Text('Total: ₹${order.total.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// **NEW:** Builds the worker card
  Widget _buildWorkerCard(ThemeData theme) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(Icons.person, color: theme.colorScheme.onPrimary),
          backgroundColor: theme.colorScheme.primary,
        ),
        title: Text(_workerName ?? 'Worker'),
        subtitle: Text(
            (_workerPhone ?? '').isNotEmpty ? _workerPhone! : 'Phone not available'),
        trailing: (_workerPhone ?? '').isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.copy, size: 20),
          tooltip: 'Copy phone',
          onPressed: () {
            final phoneToCopy = _workerPhone ?? '';
            Clipboard.setData(ClipboardData(text: phoneToCopy));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Copied: $phoneToCopy')));
          },
        )
            : null,
      ),
    );
  }

  /// **NEW:** Builds the rating card
  Widget _buildRatingCard(OrderModel order, ThemeData theme) {
    // Case 1: Already rated, not in edit mode
    if (order.serviceRating != null && !_isEditingRating) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: const Text('Your Rating'),
          subtitle: Text('Service: ${order.serviceRating!.toStringAsFixed(1)} stars'),
          trailing: TextButton(
            child: const Text('Edit'),
            onPressed: () async {
              setState(() {
                _isEditingRating = true;
                _selectedRating = order.serviceRating;
                _selectedWorkerRating = order.workerRating;
              });
              await _prefillExistingReview();
            },
          ),
        ),
      );
    }

    // Case 2: Not rated yet, or in edit mode
    return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Rate this service', style: theme.textTheme.titleMedium),
              _buildStarRating(),
              if (order.workerId != null) ...[
                const SizedBox(height: 12),
                Text('Rate the worker (optional)',
                    style: theme.textTheme.titleMedium),
                _buildWorkerStarRating(),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _reviewController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Write a short review (optional)',
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_isEditingRating) ...[
                    Expanded(
                      child: TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          setState(() {
                            _isEditingRating = false;
                            _selectedRating = order.serviceRating;
                            _selectedWorkerRating = order.workerRating;
                            _reviewController.text = '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting || _selectedRating == null
                          ? null
                          : _submitRating,
                      child: _isSubmitting
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Submit Rating'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  // --- Main Build Method (Refactored) ---

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final theme = Theme.of(context);

    // --- Date Parsing (Unchanged) ---
    DateTime createdDate;
    try {
      final dynamic val = order.createdAt;
      if (val is DateTime) {
        createdDate = val;
      } else if (val is String) {
        createdDate = DateTime.parse(val);
      } else if (val is int) {
        createdDate = DateTime.fromMillisecondsSinceEpoch(val);
      } else {
        createdDate = (val as dynamic).toDate() as DateTime;
      }
    } catch (_) {
      createdDate = DateTime.now();
    }
    DateTime? scheduledDate;
    try {
      final dynamic sval = order.scheduledAt;
      if (sval is DateTime) scheduledDate = sval;
      else if (sval is String) scheduledDate = DateTime.parse(sval);
      else if (sval is int) scheduledDate = DateTime.fromMillisecondsSinceEpoch(sval);
      else if (sval != null) scheduledDate = (sval as dynamic).toDate() as DateTime;
    } catch (_) {
      scheduledDate = null;
    }
    // --- End Date Parsing ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          // 1. Order Summary Card
          _buildSummaryCard(order, createdDate, theme),

          // 2. Order Status Timeline
          _buildSectionHeader('Order Status'),
          _buildStatusTimeline(order.orderStatus),

          // 3. Delivery & Items Card
          _buildSectionHeader('Service Details', icon: Icons.inventory_2_outlined),
          // Only show scheduled date in the delivery card when the order is assigned.
          _buildDeliveryItemsCard(order, order.orderStatus == OrderStatus.assigned ? scheduledDate : null, theme),

          // 4. Assigned Worker Card
          if (order.workerId != null &&
              (order.orderStatus == OrderStatus.assigned ||
                  order.orderStatus == OrderStatus.on_my_way ||
                  order.orderStatus == OrderStatus.arrived ||
                  order.orderStatus == OrderStatus.in_progress ||
                  order.orderStatus == OrderStatus.completed)) ...[
            _buildSectionHeader('Assigned Worker', icon: Icons.person_outline),
            _buildWorkerCard(theme),
          ],

          // 5. Rating Card
          if (order.orderStatus == OrderStatus.completed) ...[
            _buildSectionHeader('Feedback', icon: Icons.reviews_outlined),
            _buildRatingCard(order, theme),
          ],

          // 6. Metadata (for debug)
          const SizedBox(height: 24),
          Text(
            'Order ID: ${order.id}\nUser: ${order.userId}',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
