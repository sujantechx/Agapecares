// lib/features/auth/data/repositories/auth_repository.dart

// 🎯 FIX: Add this import statement for the dartz package.
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../../shared/models/user_model.dart';
import '../datasources/auth_remote_ds.dart';

/// Abstract contract for the authentication repository.
abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp({required String phoneNumber});
  Future<Either<Failure, UserModel>> verifyOtp({required String otp});
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> sendOtp({required String phoneNumber}) async {
    try {
      await remoteDataSource.sendOtp(phoneNumber);
      return const Right(null); // Right signifies success
    } catch (e) {
      return Left(ServerFailure('Failed to send OTP: ${e.toString()}')); // Left signifies failure
    }
  }

  @override
  Future<Either<Failure, UserModel>> verifyOtp({required String otp}) async {
    try {
      final user = await remoteDataSource.verifyOtp(otp);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure('Failed to verify OTP: ${e.toString()}'));
    }
  }
}