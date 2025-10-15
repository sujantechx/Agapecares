// filepath: lib/features/user_app/features/data/fixed_data/all_services.dart
// Sample fixed data list of services used by the user app and admin create form.

import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/core/models/service_option_model.dart';
import 'package:agapecares/core/models/subscription_plan_model.dart';

/// A small, maintainable list of service fixtures for local testing or
/// to bootstrap the app UI when Firestore is empty. Admins can create
/// services using the same `ServiceModel` shape.
final List<ServiceModel> allServices = [
  ServiceModel(
    id: '1',
    name: 'Full Home Cleaning',
    description: 'Complete home cleaning covering all rooms and surfaces.',
    category: 'Home Cleaning',
    basePrice: 2499.0,
    estimatedTimeMinutes: 300,
    imageUrl: 'assets/images/Home_C.png',
    images: ['assets/images/Home_C.png'],
    options: [
      ServiceOption(name: '1 BHK Home', price: 2499),
      ServiceOption(name: '2Home BHK ', price: 3499),
      ServiceOption(name: '3 BHK Home', price: 4499),
      ServiceOption(name: '4 BHK / Villa', price: 5999),
    ],
    subscriptionPlans: [
      SubscriptionPlan(name: 'Monthly', durationInMonths: 1, discountPercent: 10.0),
      SubscriptionPlan(name: '3-Month', durationInMonths: 3, discountPercent: 15.0),
    ],
  ),

  ServiceModel(
    id: '2',
    name: 'Sofa Deep Cleaning',
    description: 'Deep wash and stain removal for sofas and upholstery.',
    category: 'Sofa Cleaning',
    basePrice: 899.0,
    estimatedTimeMinutes: 90,
    imageUrl: 'assets/images/Sofa_C.png',
    images: ['assets/images/Sofa_C.png'],
    options: [
      ServiceOption(name: '2 Seater', price: 899),
      ServiceOption(name: '3 Seater', price: 1199),
      ServiceOption(name: '5 Seater', price: 1699),
    ],
    subscriptionPlans: [],
  ),

  ServiceModel(
    id: '3',
    name: 'Kitchen Deep Cleaning',
    description: 'Degreasing, cabinet cleaning, chimney and appliance exterior cleaning.',
    category: 'Kitchen Cleaning',
    basePrice: 1299.0,
    estimatedTimeMinutes: 120,
    imageUrl: 'assets/images/Kitchen_C.png',
    images: ['assets/images/Kitchen_C.png'],
    options: [
      ServiceOption(name: 'Standard Kitchen', price: 1299),
      ServiceOption(name: 'With Chimney Clean', price: 1699),
    ],
    subscriptionPlans: [
      SubscriptionPlan(name: 'Monthly', durationInMonths: 1, discountPercent: 5.0),
    ],
  ),

  ServiceModel(
    id: '4',
    name: 'Bathroom Sanitization',
    description: 'Disinfectant deep-clean for bathroom tiles, fixtures and drains.',
    category: 'Bathroom Cleaning',
    basePrice: 499.0,
    estimatedTimeMinutes: 45,
    imageUrl: 'assets/images/Bathroom_C.png',
    images: ['assets/images/Bathroom_C.png'],
    options: [],
    subscriptionPlans: [],
  ),
];

