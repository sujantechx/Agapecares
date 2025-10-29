// dart
// File: `lib/features/user_app/presentation/pages/user_home_page.dart`

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/features/user_app/features/services/logic/service_bloc.dart';
import 'package:agapecares/features/user_app/features/services/logic/service_event.dart';
import 'package:agapecares/features/user_app/features/services/logic/service_state.dart';
import 'package:agapecares/app/theme/app_theme.dart';
import 'package:agapecares/features/user_app/features/presentation/widgets/location_search.dart' hide AppTheme;

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  // Small static data for offers/why-us retained locally
  final List<String> _offerImages = const [
    'assets/images/off1.png',
    'assets/images/off3.png',
    'assets/images/off2.png',
  ];

  final List<Map<String, dynamic>> _whyUsData = const [
    {'icon': Icons.people_alt, 'text': 'All Services in Single Umbrella'},
    {'icon': Icons.currency_rupee, 'text': 'Lower Rates using Bidding'},
    {'icon': Icons.verified_user, 'text': 'Trusted Experienced Staff'},
    {'icon': Icons.build_circle, 'text': 'Advance Technology & Equipments'},
    {'icon': Icons.thumb_up, 'text': '100% Quality Guaranteed'},
    {'icon': Icons.dashboard_customize, 'text': 'Customized Services'},
  ];

  @override
  void initState() {
    super.initState();
    // Request services from the repository via ServiceBloc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<ServiceBloc>().add(LoadServices());
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ServiceBloc, ServiceState>(builder: (context, state) {
        if (state is ServiceLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ServiceError) {
          return Center(child: Text('Failed to load services'));
        }

        final services = state is ServiceLoaded ? state.services : <ServiceModel>[];

        // compute lists from fetched services
        final popularServices = services.where((s) => ['9', '5', '6', '4', '7'].contains(s.id)).toList();
        final topServices = services.take(8).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              _buildOfferCarousel(context),
              const SizedBox(height: 10),
              const LocationSearchBar(),
              // const Divider(height: 1, thickness: 1),
              _buildSectionTitle('Cleaning Services'),
              _buildTopServicesGrid(context, topServices),
              // const SizedBox(height: 24),
              // _buildSectionTitle('Popular Cleaning Services'),
              // _buildPopularCleaningGrid(context, popularServices),
              const SizedBox(height: 24),
              _buildSectionTitle('Why Agapecares Cleaning Services?'),
              _buildWhyUsGrid(context),
              const SizedBox(height: 24),
              // _buildTestimonialCard(context),
              // const SizedBox(height: 24),
              // _buildSectionTitle('Our Client and Partners'),
              // const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOfferCarousel(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: CarouselSlider.builder(
        itemCount: _offerImages.length,
        itemBuilder: (context, index, realIdx) {
          final img = _offerImages[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: AssetImage(img), fit: BoxFit.cover),
            ),
          );
        },
        options: CarouselOptions(
          height: 180,
          viewportFraction: 0.95,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 2),
          autoPlayAnimationDuration: const Duration(milliseconds: 400),
          enlargeCenterPage: true,
          disableCenter: true,
        ),
      ),
    );
  }}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
    child: Center(
      child: Text(
        title.toUpperCase(),
        style:  TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          // color: AppTheme.textColor,
        ),
      ),
    ),
  );
}

Widget _buildTopServicesGrid(BuildContext context, List<ServiceModel> topServices) {
  return Column(
    children: [
      // Existing grid
      GridView.builder(
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
          final image = (service.images.isNotEmpty ? service.images.first : service.imageUrl);
          return GestureDetector(
            onTap: () => context.push('/service/${service.id}', extra: service),
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Column(
                children: [
                  Expanded(
                    child: image.isNotEmpty
                        ? Image.network(image, fit: BoxFit.cover, width: double.infinity)
                        : const SizedBox.shrink(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      service.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      // // New: All Services label + grid
      // _buildSectionTitle('All Services'),
      // _buildAllServicesGrid(context, topServices),
    ],
  );
}

Widget _buildAllServicesGrid(BuildContext context, List<ServiceModel> services) {
  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12.0,
      mainAxisSpacing: 12.0,
      childAspectRatio: 0.92,
    ),
    itemCount: services.length,
    itemBuilder: (context, index) {
      final service = services[index];
      final image = (service.images.isNotEmpty ? service.images.first : service.imageUrl);
      return GestureDetector(
        onTap: () => context.push('/service/${service.id}', extra: service),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Column(
            children: [
              Expanded(
                child: image.isNotEmpty
                    ? Image.network(image, fit: BoxFit.cover, width: double.infinity)
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(service.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('₹ ${service.basePrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

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
      final image = (service.images.isNotEmpty ? service.images.first : service.imageUrl);
      return GestureDetector(
        onTap: () => context.push('/service/${service.id}', extra: service),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Column(
            children: [
              Expanded(
                child: image.isNotEmpty
                    ? Image.asset(image, fit: BoxFit.cover, width: double.infinity)
                    : const SizedBox.shrink(),
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

Widget _buildWhyUsGrid(BuildContext context) {
  final whyUsData = (context.findAncestorStateOfType<_UserHomePageState>()?._whyUsData) ?? const [
    {'icon': Icons.people_alt, 'text': 'All Services in Single Umbrella'},
    {'icon': Icons.currency_rupee, 'text': 'Lower Rates using Bidding'},
    {'icon': Icons.verified_user, 'text': 'Trusted Experienced Staff'},
    {'icon': Icons.build_circle, 'text': 'Advance Technology & Equipments'},
    {'icon': Icons.thumb_up, 'text': '100% Quality Guaranteed'},
    {'icon': Icons.dashboard_customize, 'text': 'Customized Services'},
  ];

  return GridView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 16.0,
      mainAxisSpacing: 16.0,
    ),
    itemCount: whyUsData.length,
    itemBuilder: (context, index) {
      final item = whyUsData[index];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            // AppTheme.primaryColor.withOpacity(0.1) -> use withAlpha(26)
            backgroundColor: AppTheme.primaryColor.withAlpha(26),
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

Widget _buildTestimonialCard(BuildContext context) {
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

