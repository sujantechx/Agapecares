import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/service_model.dart';
import 'service_remote_data_source.dart';

class ServiceRemoteDataSourceImpl implements ServiceRemoteDataSource {
  final FirebaseFirestore _firestore;

  ServiceRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _serviceCollection => _firestore.collection('services');

  @override
  Future<List<ServiceModel>> getAllServices() async {
    final snapshot = await _serviceCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return ServiceModel.fromMap(data);
    }).toList();
  }

  @override
  Future<void> addService(ServiceModel service) async {
    final docRef = _serviceCollection.doc();
    final data = service.toMap();
    data['id'] = docRef.id;
    await docRef.set(data);
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await _serviceCollection.doc(service.id).update(service.toMap());
  }

  @override
  Future<void> deleteService(String serviceId) async {
    await _serviceCollection.doc(serviceId).delete();
  }
}
