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

  /// Compute worker stats: completed job count, total earned (sum of order.total), and average rating.
  Future<Map<String, dynamic>> fetchWorkerStats(String workerId) async {
    try {
      final q = await _firestore.collectionGroup('orders').where('workerId', isEqualTo: workerId).where('orderStatus', isEqualTo: 'complete').get();
      final docs = q.docs;
      double total = 0.0;
      int count = docs.length;
      double ratingSum = 0.0;
      int ratingCount = 0;
      for (final d in docs) {
        final data = d.data();
        final t = (data['total'] is num) ? (data['total'] as num).toDouble() : 0.0;
        total += t;
        final r = data['rating'];
        if (r != null) {
          try {
            double rv;
            if (r is num) {
              rv = r.toDouble();
            } else {
              rv = double.parse(r.toString());
            }
            ratingSum += rv;
            ratingCount += 1;
          } catch (_) {}
        }
      }
      final avgRating = ratingCount > 0 ? (ratingSum / ratingCount) : null;
      return {'completedCount': count, 'totalEarned': total, 'avgRating': avgRating};
    } catch (e) {
      debugPrint('[WorkerRepository] fetchWorkerStats failed: $e');
      return {'completedCount': 0, 'totalEarned': 0.0, 'avgRating': null};
    }
  }
}
