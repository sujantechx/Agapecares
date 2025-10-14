import 'package:agapecares/core/models/service_model.dart';
import '../../domain/repositories/service_repository.dart';
import '../data_sources/service_remote_data_source.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final ServiceRemoteDataSource remoteDataSource;

  ServiceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ServiceModel>> getAllServices() async {
    return await remoteDataSource.getAllServices();
  }

  @override
  Future<void> addService(ServiceModel service) async {
    await remoteDataSource.addService(service);
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await remoteDataSource.updateService(service);
  }

  @override
  Future<void> deleteService(String serviceId) async {
    await remoteDataSource.deleteService(serviceId);
  }
}