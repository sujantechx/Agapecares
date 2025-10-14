// Minimal WorkerProfilePage implementation to satisfy router references
import 'package:flutter/material.dart';

class WorkerProfilePage extends StatelessWidget {
  const WorkerProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Profile')),
      body: const Center(child: Text('Worker Profile Page')),
    );
  }
}
