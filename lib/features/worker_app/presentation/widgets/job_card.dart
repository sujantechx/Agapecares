import 'package:flutter/material.dart';
import 'package:agapecares/core/models/job_model.dart';
import 'package:intl/intl.dart';

/// A compact, reusable job card used on the worker dashboard.
///
/// - color-coded by status
/// - shows service name, time, short address, customer name/phone
/// - large status action button which calls [onStatusTap] with the next logical status
class JobCard extends StatelessWidget {
  final JobModel job;
  final bool isProminent;
  final VoidCallback? onTap;
  final Future<void> Function(String newStatus)? onStatusTap;
  final bool isUpdating;

  const JobCard({
    super.key,
    required this.job,
    this.isProminent = false,
    this.onTap,
    this.onStatusTap,
    this.isUpdating = false,
  });

  String _formatTime(DateTime dt) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return dt.toString();
    }
  }

  Color _statusColor(String status, BuildContext context) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return Colors.grey.shade400;
    if (s.contains('complete')) return Colors.green.shade600;
    if (s.contains('started') || s.contains('in_progress') || s.contains('on_my_way') || s.contains('arrived')) return Colors.deepOrange.shade400;
    // default assigned
    return Colors.blue.shade600;
  }

  String _nextActionLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return 'Cancelled';
    if (s.contains('complete')) return 'Completed';
    if (s.contains('on_my_way')) return 'Arrived';
    if (s.contains('arrived')) return 'Start';
    if (s.contains('started') || s.contains('in_progress')) return 'Complete';
    // default from assigned
    return 'On My Way';
  }

  String _nextActionStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return 'cancelled';
    if (s.contains('complete')) return 'completed';
    if (s.contains('on_my_way')) return 'arrived';
    if (s.contains('arrived')) return 'started';
    if (s.contains('started') || s.contains('in_progress')) return 'completed';
    return 'on_my_way';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(job.status, context);
    final nextLabel = _nextActionLabel(job.status);
    final nextStatus = _nextActionStatus(job.status);

    return Card(
      elevation: isProminent ? 6 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 6)),
          ),
          child: Row(
            children: [
              // Left: time/avatar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color,
                    child: Text((job.serviceName.isNotEmpty ? job.serviceName[0] : 'S').toUpperCase()),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Middle: details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(job.serviceName, style: TextStyle(fontSize: isProminent ? 16 : 14, fontWeight: FontWeight.bold))),
                        SizedBox(width: 8),
                        Text(job.status.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_formatTime(job.scheduledAt), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Text(job.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            // copy address or open map should be handled by parent via onTap which opens detail; keep simple here
                            if (onTap != null) onTap!();
                          },
                          child: const Icon(Icons.map, size: 18, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${job.customerName} • ${job.customerPhone}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),

              // Right: action button
              Column(
                children: [
                  isProminent
                      ? const SizedBox.shrink()
                      : const SizedBox(height: 4),
                  isUpdating
                      ? SizedBox(width: 80, height: 36, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: color),
                          onPressed: () async {
                            if (onStatusTap != null) await onStatusTap!(nextStatus);
                          },
                          child: Text(nextLabel),
                        ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
