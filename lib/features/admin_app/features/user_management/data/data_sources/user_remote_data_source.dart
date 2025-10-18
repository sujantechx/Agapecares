// Admin User Remote DataSource interface
// Purpose: Defines methods to interact with Firestore for admin operations on users.
// Note: Implements operations that return/consume `UserModel` from core models.

import 'package:agapecares/core/models/user_model.dart';

abstract class AdminUserRemoteDataSource {
  // Allow optional role filter to fetch only users with a specific role (e.g., worker or user)
  Future<List<UserModel>> getAllUsers({UserRole? role});
  Future<void> updateUserRole({required String uid, required UserRole role});
  Future<void> setUserVerification({required String uid, required bool isVerified});
  Future<void> setUserDisabled({required String uid, required bool disabled});
  Future<void> deleteUser(String uid);
}
