// 🎯 The page is now a StatefulWidget to manage the price state.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/service_list_model.dart';
import '../../../../shared/theme/app_theme.dart';
import '../widgets/service_options_widget.dart';

class ServiceDetailPage extends StatefulWidget {
  final ServiceModel service;
  const ServiceDetailPage({super.key, required this.service});

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  late final ScrollController _scrollController;
  bool _showFab = false;

  // 🎯 State variable to hold the currently selected price.
  late double _currentPrice;

  @override
  void initState() {
    super.initState();

    // 🎯 Initialize the price with the service's base/default price.
    _currentPrice = widget.service.price;

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showFab) {
        setState(() => _showFab = true);
      } else if (_scrollController.offset <= 200 && _showFab) {
        setState(() => _showFab = false);
      }
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
        background: Image.network(
          // 🎯 Using the higher quality detailImageUrl for the header.
          widget.service.iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.error, size: 100, color: Colors.red),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildServiceContent() {
    // We check if the service has options to decide whether to show the widget.
    final bool hasOptions = widget.service.options != null && widget.service.options!.isNotEmpty;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.service.name, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Vendor : ${widget.service.vendorName}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            _buildPriceAndTimeSection(), // This will now use the state variable
            const SizedBox(height: 16),
            _buildOfferBanner(),
            const SizedBox(height: 24),

            // 🎯 ADD THE NEW OPTIONS WIDGET HERE (conditionally)
            if (hasOptions)
              ServiceOptionsWidget(
                options: widget.service.options!,
                onOptionSelected: (selectedOption) {
                  // This callback updates the price in this parent widget
                  // whenever a new option is selected in the child widget.
                  setState(() {
                    _currentPrice = selectedOption.price;
                  });
                },
              ),
            if (hasOptions) const Divider(height: 48),

            _buildDetailsSection('Inclusions:', widget.service.inclusions),
            const SizedBox(height: 24),
            _buildDetailsSection('Exclusions:', widget.service.exclusions),
            const SizedBox(height: 100), // Extra space at the bottom
          ],
        ),
      ),
    );
  }
  /// 🎯 UPDATED to use the _currentPrice state variable for the main price.
  Widget _buildPriceAndTimeSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('₹ $_currentPrice', // Using the state variable
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor)),
                const SizedBox(width: 8),
                Text('₹ ${widget.service.originalPrice}',
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.subtitleColor,
                        decoration: TextDecoration.lineThrough)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppTheme.subtitleColor),
                const SizedBox(width: 4),
                Text(widget.service.estimatedTime, style: const TextStyle(color: AppTheme.subtitleColor)),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('ADD'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        )
      ],
    );
  }
  /// Builds the orange offer banner.
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

  /// A reusable widget to display a titled list of details (e.g., inclusions).
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