// filepath: c:\FlutterDev\agapecares\lib\features\worker_app\presentation\pages\create_service_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agapecares/features/user_app/features/data/repositories/service_repository.dart';
import 'package:agapecares/core/models/service_list_model.dart';

class CreateServicePage extends StatefulWidget {
  const CreateServicePage({Key? key}) : super(key: key);

  @override
  State<CreateServicePage> createState() => _CreateServicePageState();
}

class _CreateServicePageState extends State<CreateServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController();
  final _descCtr = TextEditingController();
  final _priceCtr = TextEditingController();
  final _vendorCtr = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtr.dispose();
    _descCtr.dispose();
    _priceCtr.dispose();
    _vendorCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<ServiceRepository>();
      final price = double.tryParse(_priceCtr.text.trim()) ?? 0.0;
      final model = ServiceModel(
        id: '',
        name: _nameCtr.text.trim(),
        description: _descCtr.text.trim(),
        price: price,
        originalPrice: price,
        iconUrl: '',
        detailImageUrl: '',
        vendorName: _vendorCtr.text.trim(),
        estimatedTime: '',
        offer: '',
        inclusions: const [],
        exclusions: const [],
        options: const [],
        subscriptionPlans: null,
      );
      await repo.createService(model);
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CreateServicePage] save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create service')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Service')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtr,
                decoration: const InputDecoration(labelText: 'Service Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtr,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtr,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter price' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vendorCtr,
                decoration: const InputDecoration(labelText: 'Vendor Name'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
