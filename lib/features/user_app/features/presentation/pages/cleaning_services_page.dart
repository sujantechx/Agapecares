import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routes/app_routes.dart';
import '../widgets/service_list.dart';

class CleaningServicesPage extends StatelessWidget {
  const CleaningServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning Services')),
      // Use the ServiceList widget which separates UI from logic. The
      // ServiceList will dispatch LoadServices and render loading/error/list states.
      body: const ServiceList(),
    );
  }
}