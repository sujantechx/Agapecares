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
  late TextEditingController _categoryController;
  late TextEditingController _basePriceController;
  late TextEditingController _estimatedTimeController;
  late TextEditingController _imageUrlController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _descriptionController = TextEditingController(text: widget.service?.description ?? '');
    _categoryController = TextEditingController(text: widget.service?.category ?? 'General');
    _basePriceController = TextEditingController(text: widget.service?.basePrice.toString() ?? '0.0');
    _estimatedTimeController = TextEditingController(text: widget.service?.estimatedTimeMinutes.toString() ?? '60');
    _imageUrlController = TextEditingController(text: widget.service?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _basePriceController.dispose();
    _estimatedTimeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final service = ServiceModel(
        id: widget.service?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        basePrice: double.tryParse(_basePriceController.text.trim()) ?? 0.0,
        estimatedTimeMinutes: int.tryParse(_estimatedTimeController.text.trim()) ?? 60,
        imageUrl: _imageUrlController.text.trim(),
        options: widget.service?.options ?? [],
        subscriptionPlans: widget.service?.subscriptionPlans ?? [],
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
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextFormField(
                controller: _basePriceController,
                decoration: const InputDecoration(labelText: 'Base Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a price';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              TextFormField(
                controller: _estimatedTimeController,
                decoration: const InputDecoration(labelText: 'Estimated Time (minutes)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter estimated time';
                  if (int.tryParse(value) == null) return 'Enter a valid integer';
                  return null;
                },
              ),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL (optional)'),
                keyboardType: TextInputType.url,
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
