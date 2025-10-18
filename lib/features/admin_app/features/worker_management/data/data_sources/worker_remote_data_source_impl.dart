// Admin Worker Remote DataSource - Firestore implementation
// Purpose: Implements worker-related Firestore operations for admin features.
// Note: Maps Firestore documents to `WorkerModel` or `UserModel` as needed.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/worker_model.dart';
import 'worker_remote_data_source.dart';

class AdminWorkerRemoteDataSourceImpl implements AdminWorkerRemoteDataSource {
  final FirebaseFirestore _firestore;
  AdminWorkerRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _workers => _firestore.collection('workers');

  @override
  Future<List<WorkerModel>> getAllWorkers() async {
    // Primary source: dedicated `workers` collection
    final snap = await _workers.get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => WorkerModel.fromFirestore(d)).toList();
    }

    // Fallback: some projects keep worker profiles only as users with role='worker'.
    // Query the `users` collection for role == 'worker' and map them into WorkerModel
    final usersSnap = await _firestore.collection('users').where('role', isEqualTo: 'worker').get();
    if (usersSnap.docs.isEmpty) return <WorkerModel>[];

    return usersSnap.docs.map((d) {
      final data = d.data();
      // Construct a lightweight WorkerModel from user doc; worker-specific fields use sensible defaults.
      return WorkerModel(
        uid: d.id,
        skills: List<String>.from(data['skills'] ?? []),
        status: WorkerStatus.values.firstWhere((e) => e.name == (data['status'] as String? ?? ''), orElse: () => WorkerStatus.pending),
        ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
        ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
        onboardedAt: data['onboardedAt'] as Timestamp? ?? data['createdAt'] as Timestamp? ?? Timestamp.now(),
      );
    }).toList();
  }

  @override
  Future<void> setAvailability({required String workerId, required bool isAvailable}) async {
    // Prefer updating the dedicated workers document if it exists.
    final docRef = _workers.doc(workerId);
    final doc = await docRef.get();
    if (doc.exists) {
      // Debug: log which document we updated
      // ignore: avoid_print
      print('[AdminWorkerRemoteDS] setAvailability: updating workers/$workerId -> isAvailable=$isAvailable');
      await docRef.update({'isAvailable': isAvailable});
      return;
    }

    // Fallback: if there's no workers/{id} doc, try updating the users/{id} doc
    // Many projects store worker flags on the user document. Update a sensible field there.
    final userRef = _firestore.collection('users').doc(workerId);
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      // Debug: log fallback update
      // ignore: avoid_print
      print('[AdminWorkerRemoteDS] setAvailability: workers/$workerId missing, updating users/$workerId -> isAvailable=$isAvailable');
      await userRef.update({'isAvailable': isAvailable});
      return;
    }

    // If neither exists, surface a clear error.
    // ignore: avoid_print
    print('[AdminWorkerRemoteDS] setAvailability: worker not found: $workerId');
    throw Exception('Worker not found: $workerId');
  }

  @override
  Future<void> deleteWorker(String workerId) async {
    final docRef = _workers.doc(workerId);
    final doc = await docRef.get();
    if (doc.exists) {
      // Debug: removing dedicated worker doc
      // ignore: avoid_print
      print('[AdminWorkerRemoteDS] deleteWorker: deleting workers/$workerId');
      await docRef.delete();
      return;
    }

    // Fallback: If there is no dedicated worker doc, treat this as removing worker role/profile
    final userRef = _firestore.collection('users').doc(workerId);
    final userDoc = await userRef.get();
    if (userDoc.exists) {
      // Debug: demoting user document
      // ignore: avoid_print
      print('[AdminWorkerRemoteDS] deleteWorker: workers/$workerId missing, demoting users/$workerId');
      // Demote the user to a regular user and remove worker-specific fields.
      await userRef.update({
        'role': 'user',
        // Remove worker-specific fields if present
        'skills': FieldValue.delete(),
        'status': FieldValue.delete(),
        'ratingAvg': FieldValue.delete(),
        'ratingCount': FieldValue.delete(),
        'onboardedAt': FieldValue.delete(),
        'isAvailable': FieldValue.delete(),
      });
      return;
    }

    // Nothing to delete
    // ignore: avoid_print
    print('[AdminWorkerRemoteDS] deleteWorker: worker not found: $workerId');
    throw Exception('Worker not found: $workerId');
  }
}
