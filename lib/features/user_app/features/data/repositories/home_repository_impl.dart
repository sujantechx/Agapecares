import '../../../../../core/models/service_list_model.dart';
import 'home_repository.dart';
import 'package:agapecares/features/user_app/features/data/fixed_data/all_services.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<List<ServiceModel>> getServices() async {
    // Simulate network latency and return the in-memory list
    await Future.delayed(const Duration(milliseconds: 300));
    return ServiceStore.instance.fetchAll();
  }

  @override
  Future<List<String>> getBannerImages() async {
    // Return a small set of banner placeholders
    return [
      'assets/images/off1.png',
      'assets/images/off2.png',
      'assets/images/off3.png',
    ];
  }
}