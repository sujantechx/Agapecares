import '../../../../../core/models/service_model.dart';
import 'home_repository.dart';
import 'package:agapecares/features/user_app/features/data/fixed_data/all_services.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<List<ServiceModel>> getServices() async {
    // Simulate network latency and return the in-memory fixed data list `allServices`.
    // The previous code referenced `ServiceStore.instance.fetchAll()` which does not
    // exist in the codebase and caused an undefined symbol error. Using `allServices`
    // (created under features/data/fixed_data) keeps this repository purely local
    // and suitable for UI previews or when Firestore is not used.
    await Future.delayed(const Duration(milliseconds: 300));
    return allServices;
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