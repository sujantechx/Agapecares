// dart
// File: `lib/features/user_app/presentation/pages/user_home_page.dart`

import 'package:agapecares/features/user_app/data/fixed_data/all_services.dart' as all_services;
import 'package:agapecares/shared/models/service_list_model.dart';
import 'package:carousel_slider/carousel_options.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/location_search.dart';

class Offer {
  final String imageUrl;
  const Offer({required this.imageUrl});
}

class UserHomePage extends StatelessWidget {
  UserHomePage({super.key});

  // --- DUMMY DATA SETS ---
  final List<Offer> _offers = const [
    Offer(imageUrl: "assets/images/off1.png"),
    Offer(imageUrl: "assets/images/off3.png"),
    Offer(imageUrl: "assets/images/off2.png"),
  ];

  final List<Map<String, dynamic>> whyUsData = [
    {'icon': Icons.people_alt, 'text': 'All Services in Single Umbrella'},
    {'icon': Icons.currency_rupee, 'text': 'Lower Rates using Bidding'},
    {'icon': Icons.verified_user, 'text': 'Trusted Experienced Staff'},
    {'icon': Icons.build_circle, 'text': 'Advance Technology & Equipments'},
    {'icon': Icons.thumb_up, 'text': '100% Quality Guaranteed'},
    {'icon': Icons.dashboard_customize, 'text': 'Customized Services'},
  ];

  // fetch once per widget instance
  final Future<List<ServiceModel>> _servicesFuture = all_services.ServiceStore.instance.fetchAll();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServiceModel>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final services = snapshot.data ?? <ServiceModel>[];
        // compute lists from fetched services
        final popularServices = services.where((s) => ['9', '5', '6', '4', '7'].contains(s.id)).toList();
        final topServices = services.take(8).toList();

        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                _buildOfferCarousel(),
                const SizedBox(height: 10),
                const LocationSearchBar(),
                const Divider(height: 1, thickness: 1),
                _buildSectionTitle('Services'),
                _buildTopServicesGrid(context, topServices),
                const SizedBox(height: 24),
                _buildSectionTitle('Popular Cleaning Services'),
                _buildPopularCleaningGrid(context, popularServices),
                const SizedBox(height: 24),
                _buildSectionTitle('Why Agapecares Cleaning Services?'),
                _buildWhyUsGrid(),
                const SizedBox(height: 24),
                _buildTestimonialCard(),
                const SizedBox(height: 24),
                _buildSectionTitle('Our Client and Partners'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOfferCarousel() {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: CarouselSlider.builder(
        itemCount: _offers.length,
        itemBuilder: (_, index, __) {
          return Container(
            margin: const EdgeInsets.only(left: 11),
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(_offers[index].imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
        options: CarouselOptions(
          autoPlay: true,
          viewportFraction: 1,
          autoPlayInterval: const Duration(seconds: 3),
          autoPlayCurve: Curves.fastOutSlowIn,
        ),
      ),
    );
  }
}

/// A helper widget to create consistent section titles.
Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: AppTheme.textColor,
      ),
    ),
  );
}

/// Builds the top 3x2 grid of main services.
Widget _buildTopServicesGrid(BuildContext context, List<ServiceModel> topServices) {
  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 5.0,
      mainAxisSpacing: 5.0,
      childAspectRatio: 0.9,
    ),
    itemCount: topServices.length,
    itemBuilder: (context, index) {
      final service = topServices[index];
      return GestureDetector(
        onTap: () => context.push('/service-details', extra: service),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  service.iconUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  service.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Builds the 3x2 grid for popular cleaning services.
Widget _buildPopularCleaningGrid(BuildContext context, List<ServiceModel> popularCleaningServices) {
  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 12.0,
      mainAxisSpacing: 12.0,
      childAspectRatio: 0.9,
    ),
    itemCount: popularCleaningServices.length,
    itemBuilder: (context, index) {
      final service = popularCleaningServices[index];
      return GestureDetector(
        onTap: () => context.push('/service-details', extra: service),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  service.iconUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  service.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Builds the grid for the "Why Us" section.
Widget _buildWhyUsGrid() {
  // Access to whyUsData is via closure in this file; fine as top-level.
  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
    ),
    itemCount: 6,
    itemBuilder: (context, index) {
      final item = (context.findAncestorWidgetOfExactType<UserHomePage>()! as UserHomePage).whyUsData[index];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Icon(item['icon'], color: AppTheme.primaryColor, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            item['text'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      );
    },
  );
}

/// Builds the testimonial card.
Widget _buildTestimonialCard() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.format_quote, color: AppTheme.primaryColor, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Downloaded this app for taking Termite Treatment for my home. And in the end very satisfied with the services provided.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: AppTheme.subtitleColor),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber)),
            ),
            const SizedBox(height: 16),
            const Text('Jyothi Madre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Chennai', style: TextStyle(color: AppTheme.subtitleColor)),
          ],
        ),
      ),
    ),
  );
}
