import '../../../../../shared/models/service_model.dart';

abstract class ServiceRepository {
  Future<List<ServiceModel>> fetchServices();
  Future<ServiceModel> fetchServiceById(String id);
  Future<void> createService(ServiceModel service); // Admin
  Future<void> updateService(ServiceModel service); // Admin
  Future<void> deleteService(String id); // Admin
}

