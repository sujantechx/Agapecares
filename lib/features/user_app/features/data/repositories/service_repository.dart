import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/models/service_list_model.dart';


/// Simple Firestore-backed repository for services collection.
class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createService(ServiceModel service) async {
    final id = service.id.isNotEmpty ? service.id : _firestore.collection('services').doc().id;
    await _firestore.collection('services').doc(id).set(service.toMap());
  }

  Future<List<ServiceModel>> fetchAllServices() async {
    final snap = await _firestore.collection('services').get();
    return snap.docs.map((d) => ServiceModel.fromMap(d.data())).toList();
  }
}

