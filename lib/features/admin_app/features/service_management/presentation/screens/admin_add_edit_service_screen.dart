import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/core/models/service_model.dart';
import '../bloc/service_management_bloc.dart';
import '../bloc/service_management_event.dart';

class AdminAddEditServiceScreen extends StatefulWidget {
  final ServiceModel? service;

  const AdminAddEditServiceScreen({super.key, this.service});

  @override
  _AdminAddEditServiceScreenState createState() => _AdminAddEditServiceScreenState();
}

class _AdminAddEditServiceScreenState extends State<AdminAddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _descriptionController = TextEditingController(text: widget.service?.description ?? '');
    _priceController = TextEditingController(text: widget.service?.price.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final service = ServiceModel(
        id: widget.service?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        originalPrice: widget.service?.originalPrice ?? 0.0,
        iconUrl: widget.service?.iconUrl ?? '',
        detailImageUrl: widget.service?.detailImageUrl ?? '',
        vendorName: widget.service?.vendorName ?? '',
        estimatedTime: widget.service?.estimatedTime ?? '',
        offer: widget.service?.offer ?? '',
        inclusions: widget.service?.inclusions ?? [],
        exclusions: widget.service?.exclusions ?? [],
        options: widget.service?.options ?? [],
        subscriptionPlans: widget.service?.subscriptionPlans,
      );

      if (widget.service == null) {
        context.read<ServiceManagementBloc>().add(AddService(service));
      } else {
        context.read<ServiceManagementBloc>().add(UpdateService(service));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.service == null ? 'Add Service' : 'Edit Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Service Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSave,
                child: const Text('Save Service'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
