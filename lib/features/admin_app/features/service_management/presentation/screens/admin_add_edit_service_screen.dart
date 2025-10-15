import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/core/models/service_option_model.dart';
import 'package:agapecares/core/models/subscription_plan_model.dart';
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
  late TextEditingController _imagesController; // multiline: one image path per line

  // Dynamic lists for options and subscription plans (editable in UI)
  List<ServiceOption> _options = [];
  List<SubscriptionPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name ?? '');
    _descriptionController = TextEditingController(text: widget.service?.description ?? '');
    _categoryController = TextEditingController(text: widget.service?.category ?? 'General');
    _basePriceController = TextEditingController(text: widget.service?.basePrice.toString() ?? '0.0');
    _estimatedTimeController = TextEditingController(text: widget.service?.estimatedTimeMinutes.toString() ?? '60');

    // If service exists, try to prefill images: if model stores single image, place it on first line
    final initialImages = <String>[];
    if (widget.service != null && widget.service!.imageUrl.isNotEmpty) {
      initialImages.add(widget.service!.imageUrl);
    }
    _imagesController = TextEditingController(text: initialImages.join('\n'));

    _options = List<ServiceOption>.from(widget.service?.options ?? []);
    _plans = List<SubscriptionPlan>.from(widget.service?.subscriptionPlans ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _basePriceController.dispose();
    _estimatedTimeController.dispose();
    _imagesController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    // parse image lines; keep first as the model's imageUrl to preserve existing model schema
    final imageLines = _imagesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final service = ServiceModel(
      id: widget.service?.id ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _categoryController.text.trim(),
      basePrice: double.tryParse(_basePriceController.text.trim()) ?? 0.0,
      estimatedTimeMinutes: int.tryParse(_estimatedTimeController.text.trim()) ?? 60,
      // NOTE: current ServiceModel keeps a single `imageUrl` string; store the first image here.
      imageUrl: imageLines.isNotEmpty ? imageLines.first : '',
      options: _options,
      subscriptionPlans: _plans,
    );

    if (widget.service == null) {
      context.read<ServiceManagementBloc>().add(AddService(service));
    } else {
      context.read<ServiceManagementBloc>().add(UpdateService(service));
    }
    Navigator.pop(context);
  }

  Future<void> _addOrEditOption({ServiceOption? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Option' : 'Edit Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Option name')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty) return; // keep simple validation
              final opt = ServiceOption(name: name, price: price);
              if (existing != null && index != null) {
                _options[index] = opt;
              } else {
                _options.add(opt);
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) setState(() {});
  }

  Future<void> _addOrEditPlan({SubscriptionPlan? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final durationCtrl = TextEditingController(text: existing?.durationInMonths.toString() ?? '1');
    final discountCtrl = TextEditingController(text: existing?.discountPercent.toString() ?? '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Plan' : 'Edit Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Plan name')),
            TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: 'Duration (months)'), keyboardType: TextInputType.number),
            TextField(controller: discountCtrl, decoration: const InputDecoration(labelText: 'Discount %'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final duration = int.tryParse(durationCtrl.text.trim()) ?? 1;
              final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty) return;
              final plan = SubscriptionPlan(name: name, durationInMonths: duration, discountPercent: discount);
              if (existing != null && index != null) {
                _plans[index] = plan;
              } else {
                _plans.add(plan);
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) setState(() {});
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

              const SizedBox(height: 12),
              // Images: multiline input, one URL/path per line. We store the first image into ServiceModel.imageUrl
              TextFormField(
                controller: _imagesController,
                decoration: const InputDecoration(labelText: 'Images (one per line)'),
                maxLines: 3,
              ),

              const SizedBox(height: 16),
              // Options list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(onPressed: () => _addOrEditOption(), icon: const Icon(Icons.add), label: const Text('Add'))
                ],
              ),
              const SizedBox(height: 8),
              ..._options.asMap().entries.map((entry) {
                final i = entry.key;
                final opt = entry.value;
                return ListTile(
                  title: Text(opt.name),
                  subtitle: Text('₹${opt.price.toStringAsFixed(0)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditOption(existing: opt, index: i)),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _options.removeAt(i)),
                    ),
                  ]),
                );
              }).toList(),

              const SizedBox(height: 12),
              // Subscription plans
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subscription Plans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(onPressed: () => _addOrEditPlan(), icon: const Icon(Icons.add), label: const Text('Add'))
                ],
              ),
              const SizedBox(height: 8),
              ..._plans.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.durationInMonths} month(s) • ${p.discountPercent}% discount'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEditPlan(existing: p, index: i)),
                    IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => _plans.removeAt(i))),
                  ]),
                );
              }).toList(),

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
