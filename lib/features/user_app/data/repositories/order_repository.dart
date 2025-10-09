// File: lib/features/user_app/data/repositories/order_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/order_model.dart';
import '../../../../shared/services/local_database_service.dart';


/// Orchestrates saving orders locally and syncing to Firestore.
/// Why: keep offline-first UX and eventual consistency with backend.
class OrderRepository {
  final LocalDatabaseService _localDb;
  final FirebaseFirestore _firestore;

  OrderRepository({required LocalDatabaseService localDb, FirebaseFirestore? firestore})
      : _localDb = localDb,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> init() async {
    await _localDb.init();
  }

  /// Save order locally. Returns the saved local OrderModel (with localId set).
  Future<OrderModel> createOrder(OrderModel order) async {
    final saved = await _localDb.createOrder(order);
    // Try to upload in background; do not block the UI
    uploadOrder(saved);
    return saved;
  }

  /// Attempts to upload a single local order to Firestore.
  /// On success marks the local row as synced and updates remote id if available.
  /// Returns true when uploaded successfully, false otherwise.
  Future<bool> uploadOrder(OrderModel localOrder) async {
    try {
      final docRef = await _firestore.collection('orders').add(localOrder.toFirebaseJson());
      // mark local as synced
      if (localOrder.localId != null) {
        await _localDb.markOrderAsSynced(localOrder.localId!);
      }
      // write back remote id into Firestore doc as well
      await docRef.update({'remoteId': docRef.id});
      return true;
    } catch (e) {
      // If upload fails, keep local as unsynced. The SyncService will retry later.
      return false;
    }
  }

  /// Update the local copy of an order (e.g. set paymentId, orderStatus)
  Future<void> updateLocalOrder(OrderModel order) async {
    await _localDb.updateOrder(order);
  }

  /// Mark a local order as failed
  Future<void> markLocalOrderFailed(int localId, {String? reason}) async {
    await _localDb.markOrderAsFailed(localId, failureReason: reason);
  }

  /// Sync all unsynced orders: used by connectivity watcher/background task.
  Future<void> syncUnsynced() async {
    final unsynced = await _localDb.getUnsyncedOrders();
    for (final o in unsynced) {
      await uploadOrder(o);
    }
  }
}
