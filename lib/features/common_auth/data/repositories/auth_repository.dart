// lib/features/auth/data/repositories/auth_repository.dart
import 'package:dartz/dartz.dart';
import 'package:agapecares/core/models/user_model.dart';
import 'package:agapecares/core/services/session_service.dart'; // Import SessionService
import '../datasources/auth_remote_ds.dart';

// Failure class (can be in a separate core/error file)
class Failure {
  final String message;
  Failure(this.message);
}

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp({required String phoneNumber});
  Future<Either<Failure, UserModel>> verifyOtp({required String otp});
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final SessionService sessionService; // Add SessionService

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.sessionService, // Inject SessionService
  });

  @override
  Future<Either<Failure, void>> sendOtp({required String phoneNumber}) async {
    try {
      await remoteDataSource.sendOtp(phoneNumber);
      return const Right(null);
    } catch (e) {
      return Left(Failure('Failed to send OTP: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> verifyOtp({required String otp}) async {
    try {
      final userModel = await remoteDataSource.verifyOtp(otp);
      // On successful verification, save the user session
      await sessionService.saveUser(userModel);
      return Right(userModel);
    } catch (e) {
      return Left(Failure('Failed to verify OTP: ${e.toString()}'));
    }
  }
}