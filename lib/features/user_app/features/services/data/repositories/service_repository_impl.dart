import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../core/models/service_model.dart';

import 'service_repository.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new service document in the `services` collection.
  ///
  /// Inputs: [service] - a fully formed ServiceModel
  /// Output: Future<void> that completes when Firestore write succeeds.
  /// Errors: Firestore exceptions may be thrown by the caller.
  @override
  Future<void> createService(ServiceModel service) async {
    final id = service.id.isNotEmpty ? service.id : _firestore.collection('services').doc().id;
    await _firestore.collection('services').doc(id).set(service.toFirestore());
  }

  @override
  Future<void> deleteService(String id) async {
    await _firestore.collection('services').doc(id).delete();
  }

  @override
  Future<ServiceModel> fetchServiceById(String id) async {
    final doc = await _firestore.collection('services').doc(id).get();
    return ServiceModel.fromFirestore(doc);
  }

  /// Fetch all services from Firestore.
  ///
  /// Steps:
  ///  1. Query the `services` collection for documents.
  ///  2. Convert each document's data into a strongly typed [ServiceModel]
  ///     using `ServiceModel.fromMap`.
  ///  3. Return the list to the caller.
  ///
  /// Notes and error handling:
  ///  - If Firestore throws (network issues, permission denied, etc.) the
  ///    exception is propagated to the caller so the UI or BLoC can surface
  ///    an appropriate message. The BLoC currently maps exceptions into a
  ///    generic error state.
  ///  - This method performs a one-time read (.get()). If you need real-time
  ///    updates use a snapshot listener (collection.snapshots()).
  @override
  Future<List<ServiceModel>> fetchServices() async {
    final snapshot = await _firestore.collection('services').get();
    return snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList();
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await _firestore.collection('services').doc(service.id).set(service.toFirestore(), SetOptions(merge: true));
  }
}
