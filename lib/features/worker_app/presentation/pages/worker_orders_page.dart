// Minimal WorkerOrdersPage implementation to satisfy router references
import 'package:flutter/material.dart';

class WorkerOrdersPage extends StatelessWidget {
  const WorkerOrdersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Orders')),
      body: const Center(child: Text('Worker Orders Page')),
    );
  }
}
