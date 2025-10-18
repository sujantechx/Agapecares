import 'package:agapecares/core/models/user_model.dart';

abstract class AdminUserRepository {
  // Allow optional role filter
  Future<List<UserModel>> getAllUsers({UserRole? role});
  Future<void> updateUserRole({required String uid, required UserRole role});
  Future<void> setUserVerification({required String uid, required bool isVerified});
  Future<void> setUserDisabled({required String uid, required bool disabled});
  Future<void> deleteUser(String uid);
}
