import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../../../core/models/order_model.dart';
import 'package:agapecares/features/user_app/features/data/repositories/order_repository.dart' as user_orders_repo;

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
    // initialize selected rating from existing order rating (if present)
    _selectedRating = widget.order.serviceRating;
    _selectedWorkerRating = widget.order.workerRating;
    _order = widget.order;
    // Load worker profile if workerId is present
    if (_order.workerId != null && _order.workerId!.isNotEmpty) _loadWorkerProfile(_order.workerId!);
  }

  /// Try to fetch an existing rating document for this order and user so we
  /// can prefill the review text and rating when editing. This uses a
  /// collectionGroup query on 'ratings' which searches under both
  /// services/*/ratings and workers/*/ratings.
  Future<void> _prefillExistingReview() async {
    try {
      final cg = FirebaseFirestore.instance.collectionGroup('ratings')
          .where('orderId', isEqualTo: _order.id)
          .where('userId', isEqualTo: _order.userId)
          .limit(1);
      final snap = await cg.get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        final comment = (d['review'] as String?) ?? (d['comment'] as String?) ?? '';
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
      // best-effort – leave controller empty
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
      final success = await repo.submitRatingForOrder(order: _order, serviceRating: _selectedRating!, workerRating: _selectedWorkerRating, review: _reviewController.text.trim());
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks! Your rating has been submitted.')));
        // update local widget.order reference by setting state - rebuild with rating
        setState(() {
          // update local copy so UI reflects the submitted ratings
          _order = _order.copyWith(serviceRating: _selectedRating, workerRating: _selectedWorkerRating);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit rating. Try again.')));
      }
    } catch (e) {
      String msg = 'Error submitting rating. Please try again.';
      // Detect Cloud Functions specific errors to give actionable guidance
      if (e is FirebaseFunctionsException) {
        if (e.code == 'not-found') {
          msg = 'Rating service not available: backend function missing. Please deploy Cloud Functions.';
        } else if (e.code == 'permission-denied') {
          msg = 'Permission denied while submitting rating. Check Firestore rules and authentication.';
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = current >= starIndex;
        return IconButton(
          icon: Icon(filled ? Icons.star : Icons.star_border, color: Colors.amber),
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = current >= starIndex;
        return IconButton(
          icon: Icon(filled ? Icons.person : Icons.person_outline, color: Colors.amber),
          onPressed: () {
            setState(() => _selectedWorkerRating = starIndex.toDouble());
          },
        );
      }),
    );
  }

  Future<void> _loadWorkerProfile(String workerId) async {
    try {
      // Prefer workers/{workerId} since public worker profiles are allowed in rules
      final wdoc = await FirebaseFirestore.instance.collection('workers').doc(workerId).get();
      if (wdoc.exists) {
        final wdata = wdoc.data() ?? {};
        setState(() {
          _workerName = (wdata['name'] as String?) ?? (wdata['workerName'] as String?) ?? 'Worker';
          _workerPhone = (wdata['phoneNumber'] as String?) ?? (wdata['phone'] as String?) ?? '';
        });
        return;
      }

      // Fallback to users/{workerId} if workers doc not present
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(workerId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        setState(() {
          _workerName = (data['name'] as String?) ?? (data['displayName'] as String?) ?? 'Worker';
          _workerPhone = (data['phoneNumber'] as String?) ?? (data['phone'] as String?) ?? '';
        });
      }
    } catch (e) {
      debugPrint('[OrderDetailsPage] _loadWorkerProfile failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
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

    // Determine scheduled date if available (OrderModel.scheduledAt is usually a Timestamp)
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Order • ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Flexible(
                  child: SelectableText(
                    order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy order number',
                  onPressed: () {
                    final txt = order.orderNumber.isNotEmpty ? order.orderNumber : order.id;
                    Clipboard.setData(ClipboardData(text: txt));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $txt')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Placed: ${_formatDateTime(createdDate)}', style: const TextStyle(color: Colors.black54)),
            if (scheduledDate != null) const SizedBox(height: 6),
            if (scheduledDate != null) Text('Scheduled: ${_formatDateOnly(scheduledDate)} • Work hours: 09:00 - 18:00', style: const TextStyle(color: Colors.black54)),
            if (order.appointmentId != null) const SizedBox(height: 6),
            if (order.appointmentId != null) Text('Appointment ID: ${order.appointmentId}', style: const TextStyle(color: Colors.black54)),
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

            // Assigned worker contact (show when an assigned worker exists and order is assigned/ongoing/completed)
            if (order.workerId != null && (order.orderStatus == OrderStatus.assigned || order.orderStatus == OrderStatus.on_my_way || order.orderStatus == OrderStatus.arrived || order.orderStatus == OrderStatus.in_progress || order.orderStatus == OrderStatus.completed)) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text('Assigned worker', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_workerName ?? 'Worker', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if ((_workerPhone ?? '').isNotEmpty)
                Row(
                  children: [
                    Text('Phone: ${_workerPhone!}', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy phone',
                      onPressed: () {
                        final phoneToCopy = _workerPhone ?? '';
                        Clipboard.setData(ClipboardData(text: phoneToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $phoneToCopy')));
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 12),
            ],

            // Rating section: show when order is completed
            if (order.orderStatus == OrderStatus.completed) ...[
               const Divider(),
               const SizedBox(height: 12),
               Text('Rate your service', style: Theme.of(context).textTheme.titleMedium),
               const SizedBox(height: 8),
               // If a rating exists and we're not in edit mode: show rating summary + Edit button
               if (order.serviceRating != null && !_isEditingRating) ...[
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Row(
                         children: [
                           Text('Service rating: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                           Text(order.serviceRating!.toStringAsFixed(1), style: const TextStyle(color: Colors.black54)),
                           const SizedBox(width: 8),
                           Row(children: List.generate(order.serviceRating!.round(), (i) => const Icon(Icons.star, color: Colors.amber, size: 20))),
                         ],
                       ),
                     ),
                     TextButton.icon(
                       onPressed: () async {
                         // Enter edit mode and prefill existing review/rating if any
                         setState(() { _isEditingRating = true; _selectedRating = order.serviceRating; _selectedWorkerRating = order.workerRating; });
                         await _prefillExistingReview();
                       },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                   ],
                 ),
                 const SizedBox(height: 12),
               ] else ...[
                 // Editing mode or no prior rating: show inputs
                 // Primary: service rating (most important)
                 _buildStarRating(),
                 const SizedBox(height: 8),
                 // Optional: worker rating (secondary)
                 if (order.workerId != null) ...[
                   const Text('Rate the worker (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
                   _buildWorkerStarRating(),
                   const SizedBox(height: 8),
                 ],
                 TextField(
                   controller: _reviewController,
                   maxLines: 3,
                   decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Write a short review (optional)'),
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Expanded(
                       child: OutlinedButton(
                         onPressed: _isSubmitting || _selectedRating == null ? null : () async {
                           await _submitRating();
                           // Exit edit mode on success
                           if (mounted) setState(() => _isEditingRating = false);
                         },
                         child: _isSubmitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit rating'),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       child: ElevatedButton(
                         onPressed: () {
                           if (_isEditingRating) {
                             // Cancel editing and restore displayed values
                             setState(() {
                               _isEditingRating = false;
                               _selectedRating = order.serviceRating;
                               _selectedWorkerRating = order.workerRating;
                               _reviewController.text = '';
                             });
                           } else {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacting support...')));
                           }
                         },
                         child: Text(_isEditingRating ? 'Cancel' : 'Contact support'),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 12),
               ],
             ],

            const SizedBox(height: 8),

            // Metadata
            Text('Order ID: ${order.id}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text('User: ${order.userId}', style: const TextStyle(color: Colors.black54)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
