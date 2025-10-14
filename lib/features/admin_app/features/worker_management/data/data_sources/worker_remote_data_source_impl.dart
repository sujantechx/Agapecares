import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/worker_model.dart';
import 'worker_remote_data_source.dart';

class AdminWorkerRemoteDataSourceImpl implements AdminWorkerRemoteDataSource {
  final FirebaseFirestore _firestore;
  AdminWorkerRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _workers => _firestore.collection('workers');

  @override
  Future<List<WorkerModel>> getAllWorkers() async {
    final snap = await _workers.get();
    return snap.docs.map((d) => WorkerModel.fromFirestore(d.data(), d.id)).toList();
    }

  @override
  Future<void> setAvailability({required String workerId, required bool isAvailable}) async {
    await _workers.doc(workerId).update({'isAvailable': isAvailable});
  }

  @override
  Future<void> deleteWorker(String workerId) async {
    await _workers.doc(workerId).delete();
  }
}

