import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:agapecares/core/models/cart_item_model.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/features/user_app/features/cart/bloc/cart_bloc.dart';

import '../../payment_gateway/model/payment_models.dart';
import '../../payment_gateway/bloc/checkout_bloc.dart';
import '../../payment_gateway/bloc/checkout_event.dart';
import '../../payment_gateway/bloc/checkout_state.dart';
import '../../../../../app/routes/app_routes.dart';

/// CheckoutPage supports three modes:
/// - Single service checkout: navigator passes a `ServiceModel` via `extra`.
/// - Full-cart checkout: navigate without `extra` and CheckoutPage reads `CartBloc` state.
/// - Direct cart items: navigator passes `List<CartItemModel>` via `extra`.
class CheckoutPage extends StatefulWidget {
  final Object? extra; // can be ServiceModel or List<CartItemModel>
  const CheckoutPage({Key? key, this.extra}) : super(key: key);

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
  bool _initialized = false;
  String? _existingFirstAddress; // to compare for changes

  // New: saved addresses list and selection
  List<String> _savedAddresses = [];
  static const String _useNewAddressValue = '__NEW_ADDRESS__';
  String? _selectedAddressValue; // either an existing address string or _useNewAddressValue

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _seedUserDetails();
    }
  }

  Future<void> _seedUserDetails() async {
    try {
      // 1) Try SessionService cached user first (fast, offline-friendly)
      final session = context.read<SessionService>();
      final su = session.getUser();
      if (su != null) {
        if (su.name != null && su.name!.isNotEmpty) _nameCtrl.text = su.name!;
        if (su.email != null && su.email!.isNotEmpty) {
          _emailCtrl.text = su.email!;
        }
        if (su.phoneNumber != null && su.phoneNumber!.isNotEmpty) _phoneCtrl.text = su.phoneNumber!;
        if (su.addresses != null && su.addresses!.isNotEmpty) {
          // populate saved addresses from session
          final addrs = <String>[];
          for (final a in su.addresses!) {
            final ex = _extractAddress(a);
            if (ex != null) addrs.add(ex);
          }
          if (addrs.isNotEmpty) {
            setState(() {
              _savedAddresses = addrs;
              _selectedAddressValue = addrs.first;
              _addressCtrl.text = addrs.first;
              _existingFirstAddress = addrs.first;
            });
            return; // seeded from session
          }
        }
      }

      // 2) Try FirebaseAuth currentUser for email/phone
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        if (_emailCtrl.text.isEmpty && (fbUser.email ?? '').isNotEmpty) _emailCtrl.text = fbUser.email!;
        if (_phoneCtrl.text.isEmpty && (fbUser.phoneNumber ?? '').isNotEmpty) _phoneCtrl.text = fbUser.phoneNumber!;
      }

      // 3) Fetch user doc from Firestore for addresses (and potentially latest name/phone if you want to show)
      final uid = fbUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (_nameCtrl.text.isEmpty && data['name'] is String) _nameCtrl.text = data['name'] as String;
            if (_phoneCtrl.text.isEmpty && data['phone'] is String) _phoneCtrl.text = data['phone'] as String;
            if (data['addresses'] is List && (data['addresses'] as List).isNotEmpty) {
              final addrs = <String>[];
              for (final a in (data['addresses'] as List)) {
                final ex = _extractAddress(a);
                if (ex != null) addrs.add(ex);
              }
              if (addrs.isNotEmpty) {
                setState(() {
                  _savedAddresses = addrs;
                  _selectedAddressValue = addrs.first;
                  _addressCtrl.text = addrs.first;
                  _existingFirstAddress = addrs.first;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore seed errors but log
      debugPrint('[CheckoutPage] seedUserDetails failed: $e');
    }
  }

  String? _extractAddress(dynamic entry) {
    if (entry == null) return null;
    if (entry is String) return entry;
    if (entry is Map) {
      final a = entry['address'];
      if (a is String) return a;
    }
    return null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  List<CartItemModel> _buildItemsFromExtraOrCart(BuildContext context) {
    final extra = widget.extra;
    // 1) If caller passed a List<CartItemModel>
    if (extra is List<CartItemModel>) {
      return extra;
    }
    // 2) If caller passed a ServiceModel -> build single CartItemModel
    if (extra is ServiceModel) {
      final s = extra;
      final optionName = s.options.isNotEmpty ? s.options.first.name : '';
      final price = s.options.isNotEmpty ? s.options.first.price : s.basePrice;
      return [
        CartItemModel(
          serviceId: s.id,
          serviceName: s.name,
          optionName: optionName,
          quantity: 1,
          unitPrice: price,
        )
      ];
    }

    // 3) No extra provided: attempt to read CartBloc state (full-cart checkout)
    try {
      final cartState = context.read<CartBloc>().state;
      return cartState.items;
    } catch (e) {
      // If CartBloc not available or error, return empty list
      return [];
    }
  }

  double _totalForItems(List<CartItemModel> items) {
    return items.fold(0.0, (prev, el) => prev + (el.unitPrice * el.quantity));
  }

  // Helper: detect presence of CheckoutBloc to avoid ProviderNotFoundException.
  // If the app didn't provide CheckoutBloc above this page, we gracefully
  // disable checkout actions and show a helpful message instead of crashing.
  bool _hasCheckoutBloc(BuildContext ctx) {
    try {
      // read will throw if not found
      final _ = ctx.read<CheckoutBloc>();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItemsFromExtraOrCart(context);
    final total = _totalForItems(items);
    // Try to read the CheckoutBloc instance safely. Using the instance directly
    // with BlocListener.value and BlocBuilder(bloc: ...) prevents a race where
    // the provider existed during an earlier build but is no longer an ancestor
    // of the listener/builder when Flutter attaches the widget tree (causing
    // ProviderNotFoundException). If no bloc is available, `checkoutBloc` is null
    // and we render a disabled checkout button with an informative message.
    CheckoutBloc? checkoutBloc;
    try {
      checkoutBloc = context.read<CheckoutBloc>();
    } catch (_) {
      checkoutBloc = null;
    }

    // Build the main form; if CheckoutBloc exists, wrap with BlocListener to react to success/errors.
    final form = Form(
      key: _formKey,
      child: ListView(
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: Text('Your cart is empty or service not found.')),
            )
          else
            ...items.map((it) => ListTile(
                  title: Text(it.serviceName),
                  subtitle: Text('${it.optionName} x${it.quantity}'),
                  trailing: Text('₹${(it.unitPrice * it.quantity).toStringAsFixed(2)}'),
                )),

          const SizedBox(height: 12),
          ListTile(
            title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),

          // Contact fields
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
            readOnly: true, // email is not writable from checkout UI
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

          // Address selector: if saved addresses available allow picking one or entering new address
          if (_savedAddresses.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedAddressValue ?? (_savedAddresses.isNotEmpty ? _savedAddresses.first : null),
              decoration: const InputDecoration(labelText: 'Saved addresses'),
              items: [
                ..._savedAddresses.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                const DropdownMenuItem(value: _useNewAddressValue, child: Text('Use a different / new address'))
              ],
              onChanged: (v) {
                setState(() {
                  _selectedAddressValue = v;
                  if (v == _useNewAddressValue) {
                    _addressCtrl.text = '';
                  } else if (v != null) {
                    _addressCtrl.text = v;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
          ],

          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter address' : null,
          ),

          const SizedBox(height: 12),
          // Use a dropdown to select payment method to avoid deprecated RadioListTile API
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'razorpay', child: Text('Pay with Razorpay')),
              DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _paymentMethod = v);
            },
          ),
          const SizedBox(height: 16),

          // If there is a CheckoutBloc available, show the real button wired to it.
          // Otherwise show a disabled informative button to avoid ProviderNotFoundException.
          Builder(builder: (btnCtx) {
            if (checkoutBloc == null) {
              return ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(btnCtx).showSnackBar(const SnackBar(content: Text('Checkout not available: missing CheckoutBloc provider.')));
                },
                child: const Text('Place Order (Unavailable)'),
              );
            }

            // We have a bloc -> use BlocBuilder to react to inProgress state safely
            return BlocBuilder<CheckoutBloc, CheckoutState>(
              bloc: checkoutBloc,
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: state.isInProgress
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (items.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to checkout')));
                            return;
                          }

                          // If user selected one of saved addresses and didn't edit address text, we
                          // already set _addressCtrl accordingly. If user selected 'new', the text must be provided.
                          // Persist address if changed/new
                          await _maybePersistAddressChange(context);

                          final req = PaymentRequest(
                            totalAmount: total,
                            userEmail: _emailCtrl.text.trim(),
                            userPhone: _phoneCtrl.text.trim(),
                            userName: _nameCtrl.text.trim(),
                            userAddress: _addressCtrl.text.trim(),
                            items: items.map((e) => e.toMap()).toList(),
                          );

                          // Dispatch the real checkout event through the provided bloc
                          try {
                            checkoutBloc!.add(CheckoutSubmitted(request: req, paymentMethod: _paymentMethod));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checkout failed: internal error')));
                          }
                        },
                  child: state.isInProgress ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Place Order'),
                );
              });
          })
        ],
      ),
    );

    if (checkoutBloc != null) {
      // Safe to add BlocListener using the explicit bloc instance to avoid provider lookup
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: BlocListener<CheckoutBloc, CheckoutState>(
            bloc: checkoutBloc!,
            listener: (context, state) {
              if (state.isInProgress) return;
              if (state.successMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.successMessage!)));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    try {
                      GoRouter.of(context).go(AppRoutes.orders);
                      return;
                    } catch (_) {}
                    try {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.orders);
                      return;
                    } catch (_) {}
                  } catch (_) {}
                });
              }
              if (state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    try {
                      GoRouter.of(context).go(AppRoutes.orders);
                      return;
                    } catch (_) {}
                    try {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.orders);
                      return;
                    } catch (_) {}
                  } catch (_) {}
                });
              }
            },
            child: form,
          ),
        ),
      );
    }

    // No bloc -> show form but without listener
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(padding: const EdgeInsets.all(12.0), child: form),
    );
  }

  Future<void> _maybePersistAddressChange(BuildContext ctx) async {
    try {
      final newAddr = _addressCtrl.text.trim();
      if (newAddr.isEmpty) return;
      // Only persist if changed from the existing first address
      if (_existingFirstAddress != null && _existingFirstAddress == newAddr) return;

      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null || fbUser.uid.isEmpty) {
        // not logged in; can't persist
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('users').doc(fbUser.uid);
      // Add address to addresses array (don't overwrite existing array). Use a simple map with 'address' key.
      await userRef.set({
        'addresses': FieldValue.arrayUnion([{'address': newAddr}])
      }, SetOptions(merge: true));

      // Update the cached session if present to reflect the saved address for immediate UX
      try {
        final session = ctx.read<SessionService>();
        final su = session.getUser();
        if (su != null) {
          final current = su.addresses ?? [];
          // prevent duplicates: remove if already present
          final normalized = current.where((e) => _extractAddress(e) != newAddr).toList();
          normalized.insert(0, {'address': newAddr});
          session.saveUser(su.copyWith(addresses: normalized));
        }
      } catch (_) {}

      _existingFirstAddress = newAddr;
      // Reflect in local saved addresses list so UX updates immediately
      setState(() {
        if (!_savedAddresses.contains(newAddr)) {
          _savedAddresses.insert(0, newAddr);
        }
        _selectedAddressValue = newAddr;
      });

      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Address saved')));
    } catch (e) {
      debugPrint('[CheckoutPage] failed to persist address: $e');
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to save address')));
    }
  }
}
