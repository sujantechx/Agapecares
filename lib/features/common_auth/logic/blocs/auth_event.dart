// lib/features/common_auth/logic/bloc/auth_event.dart
import 'package:equatable/equatable.dart';
import 'package:agapecares/core/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// Dispatched when the BLoC should check the current auth status.
class AuthStatusChanged extends AuthEvent {
  final UserModel? user;
  const AuthStatusChanged(this.user);
  @override
  List<Object?> get props => [user];
}

/// Dispatched to request login with email and password.
class AuthLoginWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthLoginWithEmailRequested({required this.email, required this.password});
}

/// Dispatched to request registration with email, password, and other details.
class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String phone;
  final UserRole role;
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.phone,
    required this.role,
  });
}

/// Dispatched to request sending a phone OTP.
class AuthSendOtpRequested extends AuthEvent {
  final String phoneNumber;
  const AuthSendOtpRequested(this.phoneNumber);
}

/// Dispatched to verify a phone OTP.
class AuthVerifyOtpRequested extends AuthEvent {
  final String verificationId;
  final String otp;
  final String? name;
  final String? email;
  final UserRole? role;
  const AuthVerifyOtpRequested({required this.verificationId, required this.otp, this.name, this.email, this.role});

  @override
  List<Object?> get props => [verificationId, otp, name, email, role];
}

/// Dispatched to sign the user out.
class AuthSignOutRequested extends AuthEvent {}