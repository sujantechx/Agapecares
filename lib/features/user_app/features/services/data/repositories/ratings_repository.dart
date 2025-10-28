import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../core/models/review_model.dart';

/// Small repository to fetch ratings data for services/workers. This file
/// intentionally contains only read operations (fetching ratings and user
/// display names). Writes (submits/updates) are handled by submit-capable
/// repositories (for example `OrderRepository`) elsewhere.
class RatingsRepository {
  final FirebaseFirestore _firestore;

  RatingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetch service-level ratings ordered by createdAt desc.
  Future<List<ReviewModel>> fetchServiceRatings(String serviceId) async {
    final snap = await _firestore
        .collection('services')
        .doc(serviceId)
        .collection('ratings')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ReviewModel.fromFirestore(d)).toList();
  }

  /// Batch fetch user display names for the provided userIds.
  /// Tries `displayName`, `name`, or falls back to uid.
  Future<Map<String, String>> fetchUserNames(Set<String> userIds) async {
    final Map<String, String> out = {};
    if (userIds.isEmpty) return out;
    // Firestore get for multiple docs
    final futures = userIds.map((uid) => _firestore.collection('users').doc(uid).get()).toList();
    final docs = await Future.wait(futures);
    for (var d in docs) {
      if (d.exists) {
        final data = d.data() ?? {};
        final name = (data['displayName'] as String?) ?? (data['name'] as String?) ?? d.id;
        out[d.id] = name;
      } else {
        out[d.id] = d.id; // fallback
      }
    }
    return out;
  }

  /// Fetch worker-level ratings ordered by createdAt desc.
  Future<List<ReviewModel>> fetchWorkerRatings(String workerId) async {
    final snap = await _firestore
        .collection('workers')
        .doc(workerId)
        .collection('ratings')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ReviewModel.fromFirestore(d)).toList();
  }
}
