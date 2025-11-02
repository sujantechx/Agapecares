// lib/features/user_app/features/presentation/pages/service_detail_page.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:agapecares/app/routes/app_routes.dart';

import '../../../../../core/models/cart_item_model.dart';
import '../../../../../core/models/service_model.dart';
import '../../../../../core/models/service_option_model.dart';
import '../../../../../core/models/subscription_plan_model.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';
import '../widgets/service_options_widget.dart';
import '../widgets/subscription_options_widget.dart';
import 'package:agapecares/features/user_app/features/services/data/repositories/ratings_repository.dart';
import 'package:agapecares/core/models/review_model.dart';

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

  // Ratings state
  final RatingsRepository _ratingsRepo = RatingsRepository();
  List<ReviewModel> _reviews = [];
  Map<String, String> _userNames = {};
  bool _loadingReviews = true;

  // Subscription mode: false = one-time, true = subscription
  bool _isSubscriptionMode = false;

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
    // Load reviews for this service
    _loadRatings();
  }

  void _calculateAndUpdatePrice() {
    final basePrice = _selectedOption.price;
    double finalPrice;
    String subtitle;
    double discountValue = 0;

    if (!_isSubscriptionMode || _selectedSubscription == null) {
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

  Future<void> _loadRatings() async {
    try {
      setState(() => _loadingReviews = true);
      final reviews = await _ratingsRepo.fetchServiceRatings(widget.service.id);
      final userIds = reviews.map((r) => r.userId).where((id) => id.isNotEmpty).toSet();
      final names = await _ratingsRepo.fetchUserNames(userIds);
      setState(() {
        _reviews = reviews;
        _userNames = names;
        _loadingReviews = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[RATINGS] failed to load: $e');
      setState(() => _loadingReviews = false);
    }
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

  Widget _buildServiceRatingRow() {
    // Compute average from fetched reviews
    final count = _reviews.length;
    if (_loadingReviews) {
      return Row(children: const [SizedBox(width: 18, height: 18, child: CircularProgressIndicator()), SizedBox(width: 8), Text('Loading ratings...')]);
    }
    if (count == 0) {
      return Row(
        children: const [
          Icon(Icons.star_border, color: Colors.amber, size: 18),
          SizedBox(width: 6),
          Text('No ratings yet', style: TextStyle(color: Colors.black54)),
        ],
      );
    }
    final avg = _reviews.map((r) => r.rating).fold<int>(0, (prev, r) => prev + r) / count;
    final fullStars = avg.floor();
    final hasHalf = (avg - fullStars) >= 0.5;
    return Row(
      children: [
        Row(
          children: List.generate(5, (i) {
            if (i < fullStars) return const Icon(Icons.star, color: Colors.amber, size: 18);
            if (i == fullStars && hasHalf) return const Icon(Icons.star_half, color: Colors.amber, size: 18);
            return const Icon(Icons.star_border, color: Colors.amber, size: 18);
          }),
        ),
        const SizedBox(width: 8),
        Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Text('($count)', style: const TextStyle(color: Colors.black54)),
      ],
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
            // Show service rating and category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildServiceRatingRow()),
                // const SizedBox(width: 12),
                // Text(widget.service.category, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 16),

            // Mode selector: One-time vs Subscription
            if (hasSubscriptions)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isSubscriptionMode ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                        foregroundColor: !_isSubscriptionMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSubscriptionMode = false;
                          _selectedSubscription = null;
                          _calculateAndUpdatePrice();
                        });
                      },
                      child: const Text('ONE TIME'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSubscriptionMode ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                        foregroundColor: _isSubscriptionMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSubscriptionMode = true;
                          // default to first plan when switching to subscription mode
                          if (widget.service.subscriptionPlans.isNotEmpty && _selectedSubscription == null) {
                            _selectedSubscription = widget.service.subscriptionPlans.first;
                          }
                          _calculateAndUpdatePrice();
                        });
                      },
                      child: const Text('SUBSCRIPTION'),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

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

            // Show subscription options only when subscription mode active
            if (hasSubscriptions && _isSubscriptionMode)
              SubscriptionOptionsWidget(
                plans: widget.service.subscriptionPlans,
                onPlanSelected: (plan) {
                  _selectedSubscription = plan;
                  _calculateAndUpdatePrice();
                },
              ),
            if (hasSubscriptions && _isSubscriptionMode) const Divider(height: 48),

            const SizedBox(height: 8),
            Text('Details', style: TextStyle(fontWeight: FontWeight.bold ,fontSize: 18),),
            const SizedBox(height: 8),
            Text(widget.service.description),
            const SizedBox(height: 16),
            _buildReviewsSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndAction() {
    final buttonText = !_isSubscriptionMode ? 'ADD' : 'ADD';
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

            final optionName = !_isSubscriptionMode ? _selectedOption.name : '${_selectedOption.name} - ${_selectedSubscription?.name ?? ''}';
            final cartItem = CartItemModel(
              serviceId: widget.service.id,
              serviceName: widget.service.name,
              optionName: optionName,
              quantity: 1,
              unitPrice: _currentPrice,
            );

            try {
              if (kDebugMode) debugPrint('CART_DEBUG: User initiating add-to-cart for serviceId=${cartItem.serviceId} option=${cartItem.optionName} (start_console)');

              context.read<CartBloc>().add(CartItemAdded(cartItem));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${widget.service.name} added to cart!'),
                  action: SnackBarAction(label: 'VIEW CART', onPressed: () {
                    final current = GoRouterState.of(context).uri.toString();
                    if (!current.startsWith(AppRoutes.cart)) {
                      GoRouter.of(context).go(AppRoutes.cart);
                    } else {
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

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Reviews',style: TextStyle(fontWeight: FontWeight.bold ,fontSize: 18),),
            // Removed write-review button: repository is read-only and reviews are submitted elsewhere
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingReviews)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('No reviews yet', style: TextStyle(color: Colors.black54)),
              SizedBox(height: 8),
            ],
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, idx) {
              final r = _reviews[idx];
              final reviewer = _userNames[r.userId] ?? r.userId;
              final created = r.createdAt.toDate().toLocal().toString().split(' ')[0];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(children: [
                  Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                  const SizedBox(width: 8),
                  Text(reviewer, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.comment != null && r.comment!.isNotEmpty) Text(r.comment!),
                    if (created.isNotEmpty) Text(created, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
