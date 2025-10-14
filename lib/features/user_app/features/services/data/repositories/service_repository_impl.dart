import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../core/models/service_list_model.dart';

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
    await _firestore.collection('services').add(service.toMap());
  }

  @override
  Future<void> deleteService(String id) async {
    await _firestore.collection('services').doc(id).delete();
  }

  @override
  Future<ServiceModel> fetchServiceById(String id) async {
    final doc = await _firestore.collection('services').doc(id).get();
    final data = doc.data();
    return ServiceModel.fromMap({
      if (data != null) ...data,
      'id': doc.id,
    });
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
    try {
      // Step 1: Query Firestore `services` collection for all documents.
      final snapshot = await _firestore.collection('services').get();

      // Step 2: Map each DocumentSnapshot into a strongly-typed ServiceModel.
      return snapshot.docs
          .map((doc) => ServiceModel.fromMap({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      // It's important to surface errors to the caller. However, returning an
      // empty list here could hide transient problems. We rethrow the error so
      // the BLoC can emit an error state and the UI can show a retry option.
      rethrow;
    }
  }

  @override
  Future<void> updateService(ServiceModel service) async {
    await _firestore.collection('services').doc(service.id).update(service.toMap());
  }
}
