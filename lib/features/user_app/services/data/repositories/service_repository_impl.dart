import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../shared/models/service_model.dart';
import 'service_repository.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createService(ServiceModel service) async {
    await _firestore.collection('services').add(service.toFirestore());
  }

  @override
  Future<void> deleteService(String id) async {
    await _firestore.collection('services').doc(id).delete();
  }

  @override
  Future<ServiceModel> fetchServiceById(String id) async {
    final doc = await _firestore.collection('services').doc(id).get();
    return ServiceModel.fromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<List<ServiceModel>> fetchServices() async {
    final snapshot = await _firestore.collection('services').get();
    return snapshot.docs
        .map((doc) => ServiceModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await _firestore
        .collection('services')
        .doc(service.id)
        .update(service.toFirestore());
  }
}

