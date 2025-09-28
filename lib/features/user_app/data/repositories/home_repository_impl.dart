

import '../../../../shared/models/service_model.dart';
import 'home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<List<ServiceModel>> getServices() async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 1));

    // Dummy data - replace with your actual data from Firebase later
    return const [
      ServiceModel(title: 'Cleaning Services', imagePath: 'resources/assets/images/cleaning.jpg'),
      ServiceModel(title: 'Full Home Cleaning', imagePath: 'resources/assets/images/full_home_cleaning.jpg'),
      ServiceModel(title: 'Female Home Salon', imagePath: 'resources/assets/images/salon.jpg'),
      ServiceModel(title: 'AC Service Repair', imagePath: 'resources/assets/images/ac_repair.jpg'),
      ServiceModel(title: 'Commercial Space', imagePath: 'resources/assets/images/commercial.jpg'),
      ServiceModel(title: 'Electrician', imagePath: 'resources/assets/images/electrician.jpg'),
      // Add more services here
    ];
  }

  @override
  Future<List<String>> getBannerImages() async {
    // Dummy banner images
    return [
      'resources/assets/images/banner1.jpg',
      'resources/assets/images/banner2.jpg',
      'resources/assets/images/banner3.jpg',
    ];
  }
}