import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:agapecares/app/routes/app_routes.dart';
import '../bloc/service_management_bloc.dart';
import '../bloc/service_management_event.dart';
import '../bloc/service_management_state.dart';
import 'package:agapecares/features/admin_app/features/service_management/presentation/widgets/service_list_item.dart';

class AdminServiceListScreen extends StatelessWidget {
  const AdminServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Load services when the screen is built
    context.read<ServiceManagementBloc>().add(LoadServices());

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Services')),
      body: BlocBuilder<ServiceManagementBloc, ServiceManagementState>(
        builder: (context, state) {
          if (state is ServiceManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ServiceManagementLoaded) {
            return ListView.builder(
              itemCount: state.services.length,
              itemBuilder: (context, index) {
                final service = state.services[index];
                return ServiceListItem(service: service);
              },
            );
          }
          if (state is ServiceManagementError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const Center(child: Text('No services found.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add screen
          context.push(AppRoutes.adminAddService);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}