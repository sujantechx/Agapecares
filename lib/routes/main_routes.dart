import 'package:dartz/dartz_streaming.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../features/user_app/cart/presentation/cart_page.dart';
import '../features/user_app/presentation/pages/about_us_page.dart';
import '../features/user_app/presentation/pages/cleaning_services_page.dart';
import '../features/user_app/presentation/pages/contact_us_page.dart';
import '../features/user_app/presentation/pages/our_blog_page.dart';
import '../features/user_app/presentation/pages/pest_control_page.dart';
import '../features/user_app/presentation/pages/service_detail_page.dart';
import '../features/user_app/presentation/pages/terms_of_use_page.dart';
import '../shared/models/service_list_model.dart';
import 'app_routes.dart';

/// Defines the top-level routes that do not belong to a specific shell or flow.
final List<RouteBase> mainRoutes = [
  GoRoute(
    path: AppRoutes.serviceDetails,
    builder: (context, state) {
      // Ensure the 'extra' is the correct type before casting.
      if (state.extra is ServiceModel) {
        return ServiceDetailPage(service: state.extra as ServiceModel);
      }
      // Return an error page or a default state if the data is incorrect.
      return Container();
    },
  ),
  GoRoute(
    path: AppRoutes.cart, // Added from our cart implementation
    builder: (context, state) => const CartPage(),
  ),
  GoRoute(
    path: AppRoutes.aboutUs,
    builder: (context, state) => const AboutUsPage(),
  ),
  GoRoute(
    path: AppRoutes.contactUs,
    builder: (context, state) => const ContactUsPage(),
  ),
  GoRoute(
    path: AppRoutes.cleaningServices,
    builder: (context, state) => const CleaningServicesPage(),
  ),
  GoRoute(
    path: AppRoutes.pestControl,
    builder: (context, state) => const PestControlPage(),
  ),
  GoRoute(
    path: AppRoutes.blog,
    builder: (context, state) => const OurBlogPage(),
  ),
  GoRoute(
    path: AppRoutes.terms,
    builder: (context, state) => const TermsOfUsePage(),
  ),
];