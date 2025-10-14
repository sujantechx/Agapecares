import 'package:agapecares/core/models/user_model.dart';

abstract class AdminUserRepository {
  Future<List<UserModel>> getAllUsers();
  Future<void> updateUserRole({required String uid, required String role});
  Future<void> setUserVerification({required String uid, required bool isVerified});
  Future<void> setUserDisabled({required String uid, required bool disabled});
  Future<void> deleteUser(String uid);
}

