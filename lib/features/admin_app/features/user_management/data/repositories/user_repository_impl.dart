import 'package:agapecares/core/models/user_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../data_sources/user_remote_data_source.dart';

class AdminUserRepositoryImpl implements AdminUserRepository {
  final AdminUserRemoteDataSource remote;
  AdminUserRepositoryImpl({required this.remote});

  @override
  Future<List<UserModel>> getAllUsers() => remote.getAllUsers();

  @override
  Future<void> updateUserRole({required String uid, required String role}) => remote.updateUserRole(uid: uid, role: role);

  @override
  Future<void> setUserVerification({required String uid, required bool isVerified}) => remote.setUserVerification(uid: uid, isVerified: isVerified);

  @override
  Future<void> setUserDisabled({required String uid, required bool disabled}) => remote.setUserDisabled(uid: uid, disabled: disabled);

  @override
  Future<void> deleteUser(String uid) => remote.deleteUser(uid);
}

