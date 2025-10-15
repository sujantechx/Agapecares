// Admin User Remote DataSource - Firestore implementation
// Purpose: Implements admin user operations (list, update role, toggle verification/disabled, delete)
// Note: Uses `users` collection in Firestore and maps to `UserModel`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'user_remote_data_source.dart';

class AdminUserRemoteDataSourceImpl implements AdminUserRemoteDataSource {
  final FirebaseFirestore _firestore;
  AdminUserRemoteDataSourceImpl({required FirebaseFirestore firestore}) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Future<List<UserModel>> getAllUsers() async {
    final snap = await _users.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  @override
  Future<void> updateUserRole({required String uid, required UserRole role}) async {
    // Store enum as string in Firestore
    await _users.doc(uid).update({'role': role.name});
  }

  @override
  Future<void> setUserVerification({required String uid, required bool isVerified}) async {
    await _users.doc(uid).update({'isVerified': isVerified});
  }

  @override
  Future<void> setUserDisabled({required String uid, required bool disabled}) async {
    await _users.doc(uid).update({'disabled': disabled});
  }

  @override
  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }
}
