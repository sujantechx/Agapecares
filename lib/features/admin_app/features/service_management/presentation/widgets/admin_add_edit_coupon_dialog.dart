// filepath: c:\FlutterDev\agapecares\lib\features\admin_app\features\service_management\presentation\widgets\admin_add_edit_coupon_dialog.dart
import 'package:agapecares/core/models/coupon_model.dart';
import 'package:agapecares/features/user_app/features/data/repositories/offer_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AdminAddEditCouponDialog extends StatefulWidget {
  final CouponModel? coupon;
  const AdminAddEditCouponDialog({Key? key, this.coupon}) : super(key: key);

  @override
  State<AdminAddEditCouponDialog> createState() => _AdminAddEditCouponDialogState();
}

class _AdminAddEditCouponDialogState extends State<AdminAddEditCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idCtr;
  late TextEditingController _descCtr;
  late TextEditingController _valueCtr;
  late TextEditingController _minOrderCtr;
  late TextEditingController _maxUsesCtr;
  CouponType _type = CouponType.fixedAmount;
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _idCtr = TextEditingController(text: c?.id ?? '');
    _descCtr = TextEditingController(text: c?.description ?? '');
    _type = c?.type ?? CouponType.fixedAmount;
    _valueCtr = TextEditingController(text: c?.value.toString() ?? '0');
    _minOrderCtr = TextEditingController(text: c?.minOrderValue?.toString() ?? '');
    _maxUsesCtr = TextEditingController(text: c?.maxUses?.toString() ?? '');
    _expiry = c?.expiryDate.toDate() ?? DateTime.now().add(const Duration(days: 30));
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _idCtr.dispose();
    _descCtr.dispose();
    _valueCtr.dispose();
    _minOrderCtr.dispose();
    _maxUsesCtr.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<OfferRepository>();
      final coupon = CouponModel(
        id: _idCtr.text.trim().toUpperCase(),
        description: _descCtr.text.trim(),
        type: _type,
        value: double.tryParse(_valueCtr.text.trim()) ?? 0.0,
        minOrderValue: _minOrderCtr.text.trim().isEmpty ? null : double.tryParse(_minOrderCtr.text.trim()),
        maxUses: _maxUsesCtr.text.trim().isEmpty ? null : int.tryParse(_maxUsesCtr.text.trim()),
        usedCount: widget.coupon?.usedCount ?? 0,
        expiryDate: Timestamp.fromDate(_expiry),
        isActive: _isActive,
      );
      await repo.addOrUpdateCoupon(coupon);
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[AdminAddEditCouponDialog] save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save coupon: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.coupon != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Coupon' : 'Add Coupon'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _idCtr,
                decoration: const InputDecoration(labelText: 'Coupon Code'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter coupon code' : null,
                enabled: !isEdit,
              ),
              TextFormField(
                controller: _descCtr,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              DropdownButtonFormField<CouponType>(
                initialValue: _type,
                items: CouponType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name == 'percentage' ? 'Percentage' : 'Flat amount')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextFormField(
                controller: _valueCtr,
                decoration: const InputDecoration(labelText: 'Value (e.g., 10 for 10%)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter value';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed <= 0) return 'Value must be greater than 0';
                  if (_type == CouponType.percentage && parsed > 100) return 'Percentage cannot exceed 100';
                  return null;
                },
              ),
              TextFormField(
                controller: _minOrderCtr,
                decoration: const InputDecoration(labelText: 'Min order value (optional)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _maxUsesCtr,
                decoration: const InputDecoration(labelText: 'Max uses (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Expiry: ${_expiry.toLocal().toString().split(' ').first}'),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _pickDate, child: const Text('Change')),
                ],
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Save')),
      ],
    );
  }
}
