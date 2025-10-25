// lib/features/user_app/features/presentation/pages/service_detail_page.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/models/service_model.dart';
import '../../../../../core/models/service_option_model.dart';
import '../../../../../core/models/subscription_plan_model.dart';
import '../../../../../core/models/cart_item_model.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';
import 'package:agapecares/app/routes/app_routes.dart';

import '../widgets/service_options_widget.dart';
import '../widgets/subscription_options_widget.dart';

class ServiceDetailPage extends StatefulWidget {
  final ServiceModel service;
  const ServiceDetailPage({super.key, required this.service});

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  late final ScrollController _scrollController;
  bool _showFab = false;

  late ServiceOption _selectedOption;
  SubscriptionPlan? _selectedSubscription;
  late double _currentPrice;
  String _priceSubtitle = 'One-time fee';
  double _activeDiscount = 0;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.service.options.isNotEmpty
        ? widget.service.options.first
        : ServiceOption(name: 'Default', price: widget.service.basePrice);
    _calculateAndUpdatePrice();
    _scrollController = ScrollController()
      ..addListener(() {
        final show = _scrollController.offset > 200;
        if (show != _showFab) setState(() => _showFab = show);
      });
  }

  void _calculateAndUpdatePrice() {
    final basePrice = _selectedOption.price;
    double finalPrice;
    String subtitle;
    double discountValue = 0;

    if (_selectedSubscription == null) {
      finalPrice = basePrice;
      subtitle = 'One-time fee';
    } else {
      discountValue = _selectedSubscription!.discountPercent;
      final pricePerService = basePrice * (1 - discountValue / 100);
      finalPrice = pricePerService * _selectedSubscription!.durationInMonths;
      subtitle = 'for ${_selectedSubscription!.durationInMonths}-month subscription';
    }

    setState(() {
      _currentPrice = finalPrice;
      _priceSubtitle = subtitle;
      _activeDiscount = discountValue;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildServiceContent(),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
              child: const Icon(Icons.arrow_upward),
            )
          : null,
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withAlpha(204),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: widget.service.imageUrl.isNotEmpty
            ? Image.network(widget.service.imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
            : const SizedBox.shrink(),
      ),
    );
  }

  SliverToBoxAdapter _buildServiceContent() {
    final hasOptions = widget.service.options.isNotEmpty;
    final hasSubscriptions = widget.service.subscriptionPlans.isNotEmpty;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.service.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(widget.service.category, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _buildPriceAndAction(),
            const SizedBox(height: 16),
            if (hasOptions)
              ServiceOptionsWidget(
                options: widget.service.options,
                onOptionSelected: (opt) {
                  _selectedOption = opt;
                  _calculateAndUpdatePrice();
                },
              ),
            if (hasOptions) const Divider(height: 48),
            if (hasSubscriptions)
              SubscriptionOptionsWidget(
                plans: widget.service.subscriptionPlans,
                onPlanSelected: (plan) {
                  _selectedSubscription = plan;
                  _calculateAndUpdatePrice();
                },
              ),
            if (hasSubscriptions) const Divider(height: 48),
            const SizedBox(height: 8),
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.service.description),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndAction() {
    final buttonText = _selectedSubscription == null ? 'ADD' : 'SUBSCRIBE';
    final originalTotalPrice = (_selectedOption.price * max(1, _selectedSubscription?.durationInMonths ?? 1)).round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeDiscount > 0)
              Text('₹ $originalTotalPrice', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
            Row(
              children: [
                Text('₹ ${_currentPrice.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (_activeDiscount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                    child: Text('${_activeDiscount.round()}% OFF', style: const TextStyle(color: Colors.green)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_priceSubtitle, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to add items to cart'), backgroundColor: Colors.orange));
                GoRouter.of(context).push(AppRoutes.login);
              }
              return;
            }

            final optionName = _selectedSubscription == null ? _selectedOption.name : '${_selectedOption.name} - ${_selectedSubscription!.name}';
            final cartItem = CartItemModel(
              serviceId: widget.service.id,
              serviceName: widget.service.name,
              optionName: optionName,
              quantity: 1,
              unitPrice: _currentPrice,
            );

            try {
              // Debug log to indicate add-to-cart sequence started. Matches requested "start_console" marker.
              if (kDebugMode) debugPrint('CART_DEBUG: User initiating add-to-cart for serviceId=${cartItem.serviceId} option=${cartItem.optionName} (start_console)');

              // Dispatch event to CartBloc which will handle local storage / remote sync and recalc totals.
              context.read<CartBloc>().add(CartItemAdded(cartItem));
              // Inform the user and give quick action to view cart. Keep message delivery non-blocking.
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${widget.service.name} added to cart!'),
                  // Use `go` to switch to the cart route inside the ShellRoute instead
                  // of `push`, which would create a new page with the same key and
                  // cause the duplicate-page-key assertion.
                  action: SnackBarAction(label: 'VIEW CART', onPressed: () {
                    // Use GoRouterState to read current URI string safely.
                    final current = GoRouterState.of(context).uri.toString();
                    if (!current.startsWith(AppRoutes.cart)) {
                      GoRouter.of(context).go(AppRoutes.cart);
                    } else {
                      // Already on cart, just close snack bar.
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    }
                  }),
                ));
              }
            } catch (e) {
              if (kDebugMode) debugPrint('CART_DEBUG: add-to-cart failed: $e');
               if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add to cart: $e')));
            }
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(buttonText),
        ),
      ],
    );
  }
}
