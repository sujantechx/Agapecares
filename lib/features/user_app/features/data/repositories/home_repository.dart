import 'package:agapecares/core/models/service_model.dart';

abstract class HomeRepository {
  Future<List<ServiceModel>> getServices();
  Future<List<String>> getBannerImages();
}