// lib/features/user_app/data/fixed_data/all_services.dart

import 'package:agapecares/core/models/service_model.dart';
import 'package:agapecares/core/models/service_option_model.dart';
import 'package:agapecares/core/models/subscription_plan_model.dart';

/// Local store provider for services (replaces Firebase-based fetches).
/// Use `ServiceStore.instance` to access methods.
class ServiceStore {
  ServiceStore._();
  static final ServiceStore instance = ServiceStore._();

  Future<List<ServiceModel>> fetchAll() async {
    return Future.value(_allServices);
  }

  Future<ServiceModel?> fetchById(String id) async {
    try {
      return Future.value(_allServices.firstWhere((s) => s.id == id));
    } catch (_) {
      return Future.value(null);
    }
  }

  Future<List<ServiceModel>> search(String query) async {
    final q = query.toLowerCase();
    final results = _allServices.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q);
    }).toList();
    return Future.value(results);
  }
}

final List<ServiceModel> _allServices = const [
  ServiceModel(
    id: '1',
    name: 'Full Home Cleaning',
    description: 'Complete home cleaning covering all rooms and surfaces.',
    category: 'Home Cleaning',
    basePrice: 2499.0,
    estimatedTimeMinutes: 300,
    imageUrl: 'assets/images/Home_C.png',
    options: [
      ServiceOption(name: '1 BHK Home', price: 2499),
      ServiceOption(name: '2 BHK Home', price: 3499),
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
    description: 'Deep cleaning for fabric and leather sofas.',
    category: 'Furniture',
    basePrice: 799.0,
    estimatedTimeMinutes: 90,
    imageUrl: 'assets/images/Sofa_C.png',
    options: [
      ServiceOption(name: '3 Seater Sofa', price: 799),
      ServiceOption(name: '5 Seater Sofa', price: 1068),
    ],
  ),
  ServiceModel(
    id: '3',
    name: 'Bathroom Deep Cleaning',
    description: 'Intensive cleaning and disinfection of bathrooms.',
    category: 'Bathroom',
    basePrice: 699.0,
    estimatedTimeMinutes: 90,
    imageUrl: 'assets/images/Bathroom_C.png',
    subscriptionPlans: [
      SubscriptionPlan(name: 'Monthly', durationInMonths: 1, discountPercent: 10.0),
    ],
  ),
  ServiceModel(
    id: '4',
    name: 'Water Tank Cleaning',
    description: 'Mechanized cleaning for overhead and underground tanks.',
    category: 'Maintenance',
    basePrice: 599.0,
    estimatedTimeMinutes: 90,
    imageUrl: 'assets/images/Water_Tank_C.png',
  ),
];