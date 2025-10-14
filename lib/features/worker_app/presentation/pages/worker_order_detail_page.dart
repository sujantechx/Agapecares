// Minimal WorkerOrderDetailPage used by router (accepts orderId param)
import 'package:flutter/material.dart';

class WorkerOrderDetailPage extends StatelessWidget {
  final String orderId;
  const WorkerOrderDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Order Detail')),
      body: Center(child: Text('Worker Order Detail: $orderId')),
    );
  }
}
