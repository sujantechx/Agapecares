// Minimal WorkerOrderDetailPage used by router (accepts orderId param)
import 'package:flutter/material.dart';
import 'package:agapecares/features/worker_app/data/repositories/worker_job_repository.dart';
import 'package:agapecares/core/models/job_model.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/blocs/worker_tasks_bloc.dart';
import '../../logic/blocs/worker_tasks_event.dart';

class WorkerOrderDetailPage extends StatefulWidget {
  final String orderId;
  const WorkerOrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<WorkerOrderDetailPage> createState() => _WorkerOrderDetailPageState();
}

class _WorkerOrderDetailPageState extends State<WorkerOrderDetailPage> with SingleTickerProviderStateMixin {
  final WorkerJobRepository _repo = WorkerJobRepository();
  JobModel? _job;
  bool _loading = true;
  bool _changingStatus = false;
  bool _disableBackNavigation = false;

  // animation to flash on status change
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _loadJob();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    setState(() => _loading = true);
    try {
      // Defensive: if the route param is missing or still the placeholder ":id",
      // avoid calling Firestore which may result in permission-denied errors
      // and unnecessary reads. Show 'Job not found' instead.
      if (widget.orderId.isEmpty || widget.orderId.contains(':')) {
        debugPrint('[WorkerOrderDetailPage] invalid orderId provided: "${widget.orderId}"');
        setState(() => _job = null);
        return;
      }
      final j = await _repo.getJobById(widget.orderId);
      setState(() {
        _job = j;
        _statusColor = _mapStatusToColor(j?.status ?? '');
      });
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] loadJob error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load job: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _mapStatusToColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete')) return Colors.green;
    if (s.contains('arrived') || s.contains('in_progress') || s.contains('started')) return Colors.deepOrange;
    if (s.contains('on_my_way') || s.contains('on_way')) return Colors.blue;
    if (s.contains('pending') || s.contains('assigned')) return Colors.amber;
    return Colors.grey;
  }

  Color _colorWithOpacity(Color c, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(alpha);
  }

  Future<void> _changeStatus(String status) async {
    if (_job == null) return;
    try {
      setState(() => _changingStatus = true);
      // Call repository with a dynamic fallback to avoid analyzer issues in some contexts
      JobModel? updated;
      try {
        updated = await _repo.updateJobStatus(_job!.id, status);
      } catch (_) {
        final repoDyn = _repo as dynamic;
        updated = await repoDyn.updateJobStatus(_job!.id, status) as JobModel?;
      }
      if (updated != null) {
        // write status history (timestamped) to Firestore (best-effort)
        await _writeStatusHistory(updated.id, status);

        setState(() {
          _job = updated;
          _statusColor = _mapStatusToColor(status);
        });

        // animate feedback
        _animController.forward().then((_) => _animController.reverse());

        // send push notification via cloud function (best-effort)
        await _notifyStatusChange(updated.id, status);

        // prevent back navigation to avoid reversal
        setState(() => _disableBackNavigation = true);

        // Ask WorkerTasksBloc to refresh lists (best-effort) and show UI feedback only if still mounted
        if (mounted) {
          try {
            context.read<WorkerTasksBloc>().add(RefreshWorkerOrders());
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${updated.status}')));
        }
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] changeStatus error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  Future<void> _writeStatusHistory(String orderId, String status) async {
    try {
      final now = FieldValue.serverTimestamp();
      final wid = await _repo.getCurrentWorkerId();
      final data = {
        'status': status,
        'updatedAt': now,
        'by': wid ?? 'unknown',
      };
      // top-level orders doc
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).collection('statusHistory').add(data);
      } catch (e) {
        debugPrint('[WorkerOrderDetailPage] failed to write top-level statusHistory: $e');
      }
      // worker mirror if available
      if (wid != null) {
        try {
          await FirebaseFirestore.instance.collection('workers').doc(wid).collection('orders').doc(orderId).collection('statusHistory').add(data);
        } catch (e) {
          debugPrint('[WorkerOrderDetailPage] failed to write worker mirror statusHistory: $e');
        }
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] writeStatusHistory error: $e');
    }
  }

  Future<void> _notifyStatusChange(String orderId, String status) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('notifyStatusChange');
      await callable.call({'orderId': orderId, 'status': status});
    } catch (e) {
      // Non-blocking: function may not exist; log and continue
      debugPrint('[WorkerOrderDetailPage] notifyStatusChange function call failed or not available: $e');
    }
  }

  // New helper: attempt to call the customer
  Future<void> _callCustomer() async {
    if (_job == null) return;
    final phone = _job!.customerPhone.trim();
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call on this device')));
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] _callCustomer error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to call: $e')));
    }
  }

  // New helper: open map for the job address (fallback to search query)
  Future<void> _viewRoute() async {
    if (_job == null) return;
    final address = (_job!.address).trim();
    if (address.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No address available')));
      return;
    }
    final encoded = Uri.encodeComponent(address);
    final googleMaps = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    try {
      final can = await canLaunchUrl(googleMaps);
      if (can) {
        await launchUrl(googleMaps, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open maps on this device')));
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] _viewRoute error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open maps: $e')));
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_job == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (picked == null) return;
      final file = picked.readAsBytes();
      final bytes = await file;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('jobs').child(_job!.id).child('completion_$now.jpg');
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      // Save URL to order document (append to completionPhotos array)
      try {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(_job!.id);
        await orderRef.update({
          'completionPhotos': FieldValue.arrayUnion([url])
        });
        // Also update local model if needed (best-effort)
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
      } catch (e) {
        debugPrint('[WorkerOrderDetailPage] failed to persist photo URL to order doc: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded but failed to save reference: $e')));
      }
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] _pickAndUploadPhoto error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    }
  }

  // OTP verification before completing a job (best-effort via cloud function 'verifyJobOtp')
  Future<bool> _verifyOtpFlow() async {
    if (_job == null) return false;
    final otp = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter OTP from customer'),
          content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'OTP')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Verify')),
          ],
        );
      },
    );

    if (otp == null || otp.isEmpty) return false;
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('verifyJobOtp');
      final res = await callable.call({'orderId': _job!.id, 'otp': otp});
      final ok = (res.data is Map && (res.data['ok'] == true || res.data['verified'] == true)) || res.data == true;
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP verification failed')));
      }
      return ok;
    } catch (e) {
      debugPrint('[WorkerOrderDetailPage] verifyJobOtp function failed or unavailable: $e');
      // Fallback: ask user to confirm without OTP
      if (!mounted) return false;
      final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('OTP unavailable'),
              content: const Text('OTP verification service is unavailable. Do you want to mark job as completed without OTP?'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes'))],
            ),
          ) ??
          false;
      return confirm;
    }
  }

  List<Widget> _buildActionButtonsLarge() {
    if (_job == null) return [];
    final status = _job!.status;
    final List<Widget> buttons = [];

    Future<void> addLarge(String label, String to, {Color? color, bool requiresOtp = false, bool requireConfirmation = false, bool allowPhotoAfter = false}) async {
      // full-width large button
      buttons.add(SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: _changingStatus
              ? null
              : () async {
                  // If completing, maybe verify OTP first
                  if (requiresOtp) {
                    final ok = await _verifyOtpFlow();
                    if (!ok) return;
                  }
                  if (requireConfirmation) {
                    final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm'),
                            content: Text('Are you sure you want to mark this job as $label?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
                            ],
                          ),
                        ) ??
                        false;
                    if (!ok) return;
                  }
                  await _changeStatus(to);
                  if (allowPhotoAfter) {
                    // prompt to upload photo as proof
                    await _pickAndUploadPhoto();
                  }
                },
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ));
      buttons.add(const SizedBox(height: 8));
    }

    switch (status) {
      case 'pending':
        addLarge('Accept', 'accepted', color: Colors.orange);
        break;
      case 'assigned':
      case 'accepted':
        addLarge('On My Way', 'on_my_way', color: Colors.blue);
        addLarge('Arrived', 'arrived', color: Colors.green);
        break;
      case 'on_way':
      case 'on_my_way':
        addLarge('Arrived', 'arrived', color: Colors.green);
        break;
      case 'arrived':
        addLarge('Start', 'in_progress', color: Colors.teal);
        addLarge('Pause', 'paused', color: Colors.grey);
        break;
      case 'in_progress':
        addLarge('Pause', 'paused', color: Colors.grey);
        addLarge('Complete', 'completed', color: Colors.green, requiresOtp: true, requireConfirmation: true, allowPhotoAfter: true);
        break;
      case 'paused':
        addLarge('Resume', 'in_progress', color: Colors.teal);
        addLarge('Complete', 'completed', color: Colors.green, requiresOtp: true, requireConfirmation: true, allowPhotoAfter: true);
        break;
      default:
        // no actions
        break;
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_disableBackNavigation,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _job == null
                ? const Center(child: Text('Job not found'))
                : Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Section: service, customer, address
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _colorWithOpacity(_statusColor, 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _colorWithOpacity(_statusColor, 0.2))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_job!.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.person_outline, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${_job!.customerName} • ${_job!.customerPhone}')),
                                IconButton(onPressed: _callCustomer, icon: const Icon(Icons.call)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.location_on, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_job!.address)),
                                IconButton(onPressed: _viewRoute, icon: const Icon(Icons.map)),
                              ])
                            ]),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Middle: instructions, checklist (placeholder), images
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.schedule, size: 16, color: Colors.black54),
                                const SizedBox(width: 8),
                                Text(DateFormat.yMMMMd().add_jm().format(_job!.scheduledAt.toLocal())),
                              ]),
                              if (_job!.scheduledEnd != null) ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.schedule_outlined, size: 16, color: Colors.black54),
                                  const SizedBox(width: 8),
                                  Text('Ends: ${DateFormat.yMMMMd().add_jm().format(_job!.scheduledEnd!.toLocal())}'),
                                ]),
                              ],
                              const SizedBox(height: 12),
                              const Text('Job Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(_job!.specialInstructions ?? 'No special instructions'),
                              const SizedBox(height: 12),
                              const Text('Inclusions', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, children: _job!.inclusions.map((i) => Chip(label: Text(i))).toList()),
                              const SizedBox(height: 12),
                              const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              // display completionPhotos if present
                              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                future: FirebaseFirestore.instance.collection('orders').doc(_job!.id).get(),
                                builder: (context, snap) {
                                  if (!snap.hasData) return const SizedBox.shrink();
                                  final data = snap.data?.data() ?? {};
                                  final List<dynamic> photos = data['completionPhotos'] is List ? data['completionPhotos'] as List : [];
                                  if (photos.isEmpty) return const Text('No photos yet');
                                  return SizedBox(
                                    height: 120,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: photos.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (context, i) {
                                        final url = photos[i] as String;
                                        return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 160, height: 120, fit: BoxFit.cover));
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ]),
                          ),
                        ),

                        // Bottom: Call, Route, Status buttons
                        Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            Expanded(child: ElevatedButton.icon(onPressed: _callCustomer, icon: const Icon(Icons.call), label: const Text('Call'))),
                            const SizedBox(width: 8),
                            Expanded(child: ElevatedButton.icon(onPressed: _viewRoute, icon: const Icon(Icons.map), label: const Text('Route'))),
                          ]),
                          const SizedBox(height: 8),
                          // large status buttons
                          ..._buildActionButtonsLarge(),
                          const SizedBox(height: 8),
                        ])
                      ],
                    ),
                  ),
      ),
    );
  }
}
