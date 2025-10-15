// Admin Service Remote DataSource - Firestore implementation
// Purpose: Implements service CRUD operations against Firestore and maps to `ServiceModel`.
// Notes: No model changes; this file documents the mappings.

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
      // Convert DocumentSnapshot to ServiceModel using fromFirestore
      return ServiceModel.fromFirestore(doc);
    }).toList();
  }

  @override
  Future<void> addService(ServiceModel service) async {
    final docRef = _serviceCollection.doc();
    final data = service.toFirestore();
    // ensure id is set on the document if the model expects it separately
    await docRef.set(data);
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await _serviceCollection.doc(service.id).update(service.toFirestore());
  }

  @override
  Future<void> deleteService(String serviceId) async {
    await _serviceCollection.doc(serviceId).delete();
  }
}
