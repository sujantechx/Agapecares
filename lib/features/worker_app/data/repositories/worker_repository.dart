import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/models/user_model.dart';

/// Simple WorkerRepository that reads/writes worker profiles and helper methods
/// for worker-related queries (assigned orders count, accept/complete shortcuts
/// may be delegated to OrderRepository).
class WorkerRepository {
  final FirebaseFirestore _firestore;

  WorkerRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserModel?> fetchWorkerProfile(String workerId) async {
    try {
      final doc = await _firestore.collection('users').doc(workerId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return UserModel.fromMap({...data, 'uid': doc.id});
    } catch (e) {
      debugPrint('[WorkerRepository] fetchWorkerProfile failed: $e');
      return null;
    }
  }

  Future<bool> updateWorkerProfile(String workerId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(workerId).set(updates, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[WorkerRepository] updateWorkerProfile failed: $e');
      return false;
    }
  }
}
