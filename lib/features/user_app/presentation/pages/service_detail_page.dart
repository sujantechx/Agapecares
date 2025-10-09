// lib/features/services/presentation/pages/service_detail_page.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:math'; // 🎯 Import for the 'max' function

import '../../../../shared/models/service_list_model.dart';
import '../../../../shared/models/service_option_model.dart';
import '../../../../shared/models/subscription_plan_model.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';
import '../../cart/data/models/cart_item_model.dart';
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

  // State variables to manage selected options and the final price.
  late ServiceOption _selectedOption;
  SubscriptionPlan? _selectedSubscription;
  late double _currentPrice;
  String _priceSubtitle = 'One-time fee';
  double _activeDiscount = 0; // 🎯 New state to hold the current discount percentage.

  @override
  void initState() {
    super.initState();

    if (widget.service.options.isNotEmpty) {
      _selectedOption = widget.service.options.first;
    } else {
      _selectedOption = ServiceOption(
        id: 'default',
        name: 'Default',
        price: widget.service.price,
      );
    }

    _calculateAndUpdatePrice();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showFab) {
        setState(() => _showFab = true);
      } else if (_scrollController.offset <= 200 && _showFab) {
        setState(() => _showFab = false);
      }
    });
  }

  void _calculateAndUpdatePrice() {
    double basePrice = _selectedOption.price;
    double finalPrice;
    String subtitle;
    double discountValue = 0; // 🎯 Local variable for discount

    if (_selectedSubscription == null) {
      finalPrice = basePrice;
      subtitle = 'One-time fee';
      discountValue = 0;
    } else {
      discountValue = _selectedSubscription!.discount;
      final discountAmount = discountValue / 100;
      final pricePerService = basePrice * (1 - discountAmount);
      final totalDeliveries = _selectedSubscription!.durationInMonths;
      finalPrice = pricePerService * totalDeliveries;
      subtitle =
      'for ${_selectedSubscription!.durationInMonths}-month subscription';
    }

    setState(() {
      _currentPrice = finalPrice;
      _priceSubtitle = subtitle;
      _activeDiscount = discountValue; // 🎯 Update the discount state
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ... (build, _buildSliverAppBar methods are unchanged)
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
        onPressed: () {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        },
        child: const Icon(Icons.arrow_upward),
      )
          : null,
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.8),
          child: IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textColor),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Image.asset(
          widget.service.iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.error, size: 100, color: Colors.red),
        ),
      ),
    );
  }

  // ... (_buildServiceContent is unchanged)
  SliverToBoxAdapter _buildServiceContent() {
    final bool hasOptions = widget.service.options.isNotEmpty;
    final bool hasSubscriptions = widget.service.subscriptionPlans != null &&
        widget.service.subscriptionPlans!.isNotEmpty;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.service.name,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Vendor : ${widget.service.vendorName}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _buildPriceAndTimeSection(), // This will now use the new state variables
            const SizedBox(height: 16),
            _buildOfferBanner(),
            const SizedBox(height: 24),
            if (hasOptions)
              ServiceOptionsWidget(
                options: widget.service.options,
                onOptionSelected: (selectedOption) {
                  _selectedOption = selectedOption;
                  _calculateAndUpdatePrice();
                },
              ),
            if (hasOptions) const Divider(height: 48),

            if (hasSubscriptions)
              SubscriptionOptionsWidget(
                plans: widget.service.subscriptionPlans!,
                onPlanSelected: (selectedPlan) {
                  _selectedSubscription = selectedPlan;
                  _calculateAndUpdatePrice();
                },
              ),
            if (hasSubscriptions) const Divider(height: 48),

            _buildDetailsSection('Inclusions:', widget.service.inclusions),
            const SizedBox(height: 24),
            _buildDetailsSection('Exclusions:', widget.service.exclusions),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // 🎯🎯🎯 THIS ENTIRE WIDGET IS REBUILT FOR THE NEW DISPLAY LOGIC 🎯🎯🎯
  Widget _buildPriceAndTimeSection() {
    final buttonText = _selectedSubscription == null ? 'ADD' : 'SUBSCRIBE';

    // Calculate the original price before any discounts, for display purposes.
    final originalTotalPrice = _selectedOption.price *
        max(1, _selectedSubscription?.durationInMonths ?? 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Price details column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If there's a discount, show the original price with a strikethrough.
            if (_activeDiscount > 0)
              Text(
                '₹ ${originalTotalPrice.round()}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.subtitleColor,
                  decoration: TextDecoration.lineThrough,
                ),
              ),

            // Main price line with the final price and discount badge.
            Row(
              children: [
                Text(
                  '₹ ${_currentPrice.round()}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Show discount badge only if a discount is active.
                if (_activeDiscount > 0)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_activeDiscount.round()}% OFF',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Subtitle for one-time fee or subscription period.
            Text(
              _priceSubtitle,
              style: const TextStyle(color: AppTheme.subtitleColor),
            ),
          ],
        ),

        // Add/Subscribe Button
// Modify the ElevatedButton inside _buildPriceAndTimeSection
        ElevatedButton.icon(
          onPressed: () {
            // 1. Create a unique ID for the cart item
            final cartItemId =
                '${widget.service.id}_${_selectedOption.id}_${_selectedSubscription?.id ?? 'onetime'}';

            // 2. Create the CartItem object
            final cartItem = CartItemModel(
              id: cartItemId,
              service: widget.service,
              selectedOption: _selectedOption,
              subscription: _selectedSubscription,
              quantity: 1, // Always add one at a time from this page
            );

            // 3. Add the event to the CartBloc
            context.read<CartBloc>().add(CartItemAdded(cartItem));

            // 4. Show a confirmation message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.service.name} added to cart!'),
                action: SnackBarAction(
                  label: 'VIEW CART',
                  onPressed: () => context.push('/cart'),
                ),
              ),
            );
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        )      ],
    );
  }

  // ... (_buildOfferBanner and _buildDetailsSection are unchanged)
  Widget _buildOfferBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Text(
        widget.service.offer,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailsSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 15, height: 1.4))),
            ],
          ),
        )),
      ],
    );
  }
}