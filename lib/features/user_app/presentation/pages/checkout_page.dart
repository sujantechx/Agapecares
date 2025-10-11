// filepath: c:\FlutterDev\agapecares\lib\features\user_app\presentation\pages\checkout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';


import '../../../../shared/models/service_list_model.dart';
import '../../../../shared/models/service_option_model.dart';
import '../../payment_gateway/model/payment_models.dart';
import '../../payment_gateway/bloc/checkout_bloc.dart';
import '../../payment_gateway/bloc/checkout_event.dart';
import '../../payment_gateway/bloc/checkout_state.dart';
import '../../cart/data/models/cart_item_model.dart';
import '../../cart/bloc/cart_bloc.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic>? serviceData;
  const CheckoutPage({Key? key, this.serviceData}) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _paymentMethod = 'razorpay';
  bool _autoFilled = false;

  @override
  void initState() {
    super.initState();
    _tryAutoFill();
  }

  Future<void> _tryAutoFill() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          // Use displayName/email/phone from Firebase user when available
          if ((user.displayName ?? '').isNotEmpty) _nameCtrl.text = user.displayName ?? '';
          if ((user.email ?? '').isNotEmpty) _emailCtrl.text = user.email ?? '';
          if ((user.phoneNumber ?? '').isNotEmpty) _phoneCtrl.text = user.phoneNumber ?? '';
          _autoFilled = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.serviceData;
    final cartState = context.watch<CartBloc>().state;

    // If serviceData is provided (single-service checkout), keep existing behavior.
    // Otherwise use the CartBloc state for multi-item cart checkout.
    final title = s?['title'] as String? ?? (cartState.items.isNotEmpty ? 'Cart Checkout' : 'Service');
    final priceFromService = (s?['price'] as num?)?.toDouble();
    final price = priceFromService ?? cartState.total;

    // Build items list: either single item from serviceData or all cart items.
    final List<CartItemModel> items = s != null
        ? [
            // Create a minimal ServiceModel and ServiceOption to construct a CartItemModel
            CartItemModel(
              id: '${s['id'] ?? 'srv_unknown'}_opt1',
              service: ServiceModel(
                id: s['id'] as String? ?? 'srv_unknown',
                name: s['title'] as String? ?? title,
                description: s['description'] as String? ?? '',
                price: (s['price'] as num?)?.toDouble() ?? 0.0,
                originalPrice: (s['price'] as num?)?.toDouble() ?? 0.0,
                iconUrl: s['image'] as String? ?? '',
                detailImageUrl: s['image'] as String? ?? '',
                vendorName: '',
                estimatedTime: '',
                offer: '',
                inclusions: const [],
                exclusions: const [],
                options: [ServiceOption(id: 'opt1', name: 'Standard', price: (s['price'] as num?)?.toDouble() ?? 0.0)],
              ),
              selectedOption: ServiceOption(id: 'opt1', name: 'Standard', price: (s['price'] as num?)?.toDouble() ?? 0.0),
              quantity: 1,
            )
          ]
        : cartState.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: BlocListener<CheckoutBloc, CheckoutState>(
          listener: (context, state) {
            if (state.isInProgress) return;
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!)));
              Navigator.of(context).pop();
            }
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('₹${price.toStringAsFixed(0)}'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter phone' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Delivery Address'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter delivery address' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('Use account info'),
                    onPressed: _tryAutoFill,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  value: 'razorpay',
                  groupValue: _paymentMethod,
                  title: const Text('Pay with Razorpay'),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                RadioListTile<String>(
                  value: 'cod',
                  groupValue: _paymentMethod,
                  title: const Text('Cash on Delivery'),
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                const SizedBox(height: 16),
                BlocBuilder<CheckoutBloc, CheckoutState>(builder: (context, state) {
                  return ElevatedButton(
                    onPressed: state.isInProgress
                        ? null
                        : () {
                            if (!_formKey.currentState!.validate()) return;
                            final req = PaymentRequest(
                              totalAmount: price,
                              userEmail: _emailCtrl.text.trim(),
                              userPhone: _phoneCtrl.text.trim(),
                              userName: _nameCtrl.text.trim(),
                              userAddress: _addressCtrl.text.trim(),
                              items: items,
                            );
                            debugPrint('[CheckoutPage] placing order with method=$_paymentMethod request=${req.userName}/${req.userEmail}/${req.userPhone} total=${req.totalAmount} items=${req.items.length}');
                            context.read<CheckoutBloc>().add(CheckoutSubmitted(request: req, paymentMethod: _paymentMethod));
                          },
                    child: state.isInProgress ? const CircularProgressIndicator() : const Text('Place Order'),
                  );
                })
              ],
            ),
          ),
        ),
      ),
    );
  }
}
