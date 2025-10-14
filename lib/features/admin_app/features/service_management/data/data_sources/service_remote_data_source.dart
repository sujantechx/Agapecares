import 'package:agapecares/core/models/service_model.dart';

abstract class ServiceRemoteDataSource {
  Future<List<ServiceModel>> getAllServices();
  Future<void> addService(ServiceModel service);
  Future<void> updateService(ServiceModel service);
  Future<void> deleteService(String serviceId);
}
