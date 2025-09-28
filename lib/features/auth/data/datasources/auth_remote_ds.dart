// lib/features/auth/data/datasources/auth_remote_ds.dart

import '../../../../shared/models/user_model.dart';

/// Abstract contract for authentication data sources.
/// This allows swapping implementations (e.g., dummy, Firebase, API).
abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phoneNumber);
  Future<UserModel> verifyOtp(String otp);
}

/// A dummy implementation for demonstration and testing purposes.
class AuthDummyDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<void> sendOtp(String phoneNumber) async {
    // Simulate a network call to send an OTP
    print('Sending OTP to $phoneNumber...');
    await Future.delayed(const Duration(seconds: 2));
    print('OTP sent successfully (dummy). The code is 123456.');
    // In a real app, this would throw an exception on failure.
  }

  @override
  Future<UserModel> verifyOtp(String otp) async {
    // Simulate a network call to verify the OTP
    print('Verifying OTP: $otp...');
    await Future.delayed(const Duration(seconds: 2));

    if (otp == '123456') {
      print('OTP verification successful (dummy).');
      // Return a dummy user model upon successful verification.
      return const UserModel(
        uid: 'dummy_user_id_123',
        phoneNumber: '+919876543210',
        name: 'John Doe',
      );
    } else {
      // Simulate a verification failure.
      print('OTP verification failed (dummy).');
      throw Exception('Invalid OTP code.');
    }
  }
}