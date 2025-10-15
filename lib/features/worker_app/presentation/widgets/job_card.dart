import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agapecares/core/models/job_model.dart';


typedef StatusCallback = Future<void> Function(String newStatus);

class JobCard extends StatelessWidget {
  final JobModel job;
  final StatusCallback? onChangeStatus;

  const JobCard({Key? key, required this.job, this.onChangeStatus}) : super(key: key);

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'assigned':
        color = Colors.orange;
        break;
      case 'on_way':
        color = Colors.blue;
        break;
      case 'arrived':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.teal;
        break;
      case 'paused':
        color = Colors.grey;
        break;
      case 'completed':
        color = Colors.greenAccent;
        break;
      default:
        color = Colors.black45;
    }
    // Use withAlpha instead of withOpacity to avoid deprecation warning
    final bg = color.withAlpha((0.12 * 255).round());
    return Chip(label: Text(status.replaceAll('_', ' ').toUpperCase()), backgroundColor: bg);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMEd().add_jm().format(job.scheduledAt.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(job.address, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 6),
                      Text('Customer: ${job.customerName} • ${job.customerPhone}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatusChip(job.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Text(dateStr, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                if (job.isCod)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.amber.withAlpha((0.12 * 255).round())),
                    child: const Text('COD', style: TextStyle(color: Colors.amber)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: job.inclusions.map((i) => Chip(label: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _buildActionButtons(context),
            )
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final List<Widget> buttons = [];

    void addButton(String label, String status, {Color? color}) {
      buttons.add(TextButton(
        onPressed: onChangeStatus == null
            ? null
            : () async {
                try {
                  await onChangeStatus!(status);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set status: $e')));
                }
              },
        child: Text(label),
        style: TextButton.styleFrom(foregroundColor: color),
      ));
    }

    // Available transitions
    switch (job.status) {
      case 'pending':
        addButton('Accept', 'assigned', color: Colors.orange);
        break;
      case 'assigned':
        addButton('On My Way', 'on_way', color: Colors.blue);
        addButton('Arrived', 'arrived', color: Colors.green);
        break;
      case 'on_way':
        addButton('Arrived', 'arrived', color: Colors.green);
        break;
      case 'arrived':
        addButton('Start Job', 'in_progress', color: Colors.teal);
        addButton('Pause', 'paused', color: Colors.grey);
        break;
      case 'in_progress':
        addButton('Pause', 'paused', color: Colors.grey);
        addButton('Complete', 'completed', color: Colors.green);
        break;
      case 'paused':
        addButton('Resume', 'in_progress', color: Colors.teal);
        addButton('Complete', 'completed', color: Colors.green);
        break;
      default:
        // no actions for completed
        break;
    }

    // Always allow calling or messaging - placeholder
    buttons.add(IconButton(
      icon: const Icon(Icons.call, color: Colors.blue),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call feature not implemented')));
      },
    ));

    return buttons;
  }
}
