import 'package:flutter/material.dart';

class CleaningServicesPage extends StatelessWidget {
  const CleaningServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning Services')),
      body: const Center(child: Text('List of all cleaning services')),
    );
  }
}