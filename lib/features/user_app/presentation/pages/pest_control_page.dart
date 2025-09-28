import 'package:flutter/material.dart';

class PestControlPage extends StatelessWidget {
  const PestControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pest Control')),
      body: const Center(child: Text('List of all Pest Control services')),
    );
  }
}