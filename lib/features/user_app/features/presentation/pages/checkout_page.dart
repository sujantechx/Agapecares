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

  // --- All non-UI logic methods (unchanged) ---

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

  bool _hasCheckoutBloc(BuildContext ctx) {
    try {
      // read will throw if not found
      final _ = ctx.read<CheckoutBloc>();
      return true;
    } catch (_) {
      return false;
    }
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

  // --- NEW: UI Helper Methods ---

  /// Builds a styled section header
  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Builds the Order Summary card
  Widget _buildOrderSummary(
      List<CartItemModel> items,
      double total,
      TextTheme textTheme,
      ColorScheme colorScheme,
      ) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Your cart is empty or service not found.',
              style: textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          ...items.map((it) => ListTile(
            title: Text(it.serviceName, style: textTheme.bodyLarge),
            subtitle: Text(
              '${it.optionName} x${it.quantity}',
              style: textTheme.bodyMedium,
            ),
            trailing: Text(
              '₹${(it.unitPrice * it.quantity).toStringAsFixed(2)}',
              style: textTheme.bodyLarge,
            ),
          )),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            title: Text(
              'Total',
              style: textTheme.titleLarge,
            ),
            trailing: Text(
              '₹${total.toStringAsFixed(2)}',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the User Details card
  Widget _buildUserDetails() {
    // Define a modern input decoration
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: inputDecoration.copyWith(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: inputDecoration.copyWith(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              readOnly: true, // email is not writable from checkout UI
              validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: inputDecoration.copyWith(
                labelText: 'Phone',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Enter phone' : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Address Section card
  Widget _buildAddressSection() {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_savedAddresses.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedAddressValue,
                isExpanded: true,
                decoration: inputDecoration.copyWith(
                  labelText: 'Saved addresses',
                  prefixIcon: const Icon(Icons.bookmark_outline),
                ),
                items: [
                  ..._savedAddresses.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(a, overflow: TextOverflow.ellipsis),
                  )),
                  const DropdownMenuItem(
                    value: _useNewAddressValue,
                    child: Text('Use a different / new address'),
                  )
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
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _addressCtrl,
              decoration: inputDecoration.copyWith(
                labelText: 'Full Address',
                prefixIcon: const Icon(Icons.home_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter address' : null,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Payment Method card
  Widget _buildPaymentSection() {
    return Card(
      child: Column(
        children: [
          RadioListTile<String>(
            title: const Text('Pay with Razorpay'),
            subtitle: const Text('Online payment (Cards, UPI)'),
            value: 'razorpay',
            groupValue: _paymentMethod,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _paymentMethod = v);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          RadioListTile<String>(
            title: const Text('Cash on Delivery'),
            subtitle: const Text('Pay after service is completed'),
            value: 'cod',
            groupValue: _paymentMethod,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _paymentMethod = v);
            },
          ),
        ],
      ),
    );
  }

  // --- Main Build Method (Refactored) ---

  @override
  Widget build(BuildContext context) {
    // Get theme data for consistent styling
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final items = _buildItemsFromExtraOrCart(context);
    final total = _totalForItems(items);
    CheckoutBloc? checkoutBloc;
    try {
      checkoutBloc = context.read<CheckoutBloc>();
    } catch (_) {
      checkoutBloc = null;
    }

    // This is the new, cleaner form body
    final formBody = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Order Summary
          _buildSectionHeader('Your Order Details', textTheme),
          _buildOrderSummary(items, total, textTheme, colorScheme),

          // 2. User Details
          _buildSectionHeader('Contact Details', textTheme),
          _buildUserDetails(),

          // 3. Address
          _buildSectionHeader('Shipping Address', textTheme),
          _buildAddressSection(),

          // 4. Payment Method
          _buildSectionHeader('Payment Method', textTheme),
          _buildPaymentSection(),

          const SizedBox(height: 24),

          // 5. Place Order Button
          Builder(builder: (btnCtx) {
            if (checkoutBloc == null) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: textTheme.titleMedium,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(btnCtx).showSnackBar(const SnackBar(
                        content: Text(
                            'Checkout not available: missing CheckoutBloc provider.')));
                  },
                  child: const Text('Place Order (Unavailable)'),
                ),
              );
            }

            // We have a bloc -> use BlocBuilder to react to inProgress state safely
            return BlocBuilder<CheckoutBloc, CheckoutState>(
              bloc: checkoutBloc,
              builder: (context, state) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      textStyle: textTheme.titleMedium,
                      backgroundColor: Color(0xFF0948EA),
                      foregroundColor: Colors.white
                    ),
                    onPressed: state.isInProgress
                        ? null
                        : () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (items.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No items to checkout')));
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
                        checkoutBloc!.add(CheckoutSubmitted(
                            request: req, paymentMethod: _paymentMethod));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                Text('Checkout failed: internal error')));
                      }
                    },
                    child: state.isInProgress
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Place Order'),
                  ),
                );
              },
            );
          })
        ],
      ),
    );

    // --- Scaffold wrapper with BlocListener (unchanged logic) ---
    if (checkoutBloc != null) {
      // Safe to add BlocListener using the explicit bloc instance
      return Scaffold(
        // appBar: AppBar(title: const Text('Checkout')),
        body: BlocListener<CheckoutBloc, CheckoutState>(
          bloc: checkoutBloc,
          listener: (context, state) {
            if (state.isInProgress) return;
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.successMessage!)));
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  try {
                    GoRouter.of(context).go(AppRoutes.orders);
                    return;
                  } catch (_) {}
                  try {
                    Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.orders);
                    return;
                  } catch (_) {}
                } catch (_) {}
              });
            }
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  try {
                    GoRouter.of(context).go(AppRoutes.orders);
                    return;
                  } catch (_) {}
                  try {
                    Navigator.of(context)
                        .pushReplacementNamed(AppRoutes.orders);
                    return;
                  } catch (_) {}
                } catch (_) {}
              });
            }
          },
          child: formBody, // Use the new formBody
        ),
      );
    }

    // No bloc -> show form but without listener
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: formBody, // Use the new formBody
    );
  }
}