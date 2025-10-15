// lib/features/common_auth/logic/bloc/auth_state.dart


import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Initial state, authentication status is unknown.
class AuthInitial extends AuthState {}

/// The user is successfully authenticated.
class Authenticated extends AuthState {
  final UserModel user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

/// The user is not authenticated.
class Unauthenticated extends AuthState {}

/// An authentication process is in progress.
class AuthLoading extends AuthState {}

/// An error occurred during authentication.
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object?> get props => [message];
}

/// A temporary state indicating an OTP has been sent and the UI should show the OTP input field.
class AuthOtpSent extends AuthState {
  final String verificationId;
  const AuthOtpSent(this.verificationId);
  @override
  List<Object?> get props => [verificationId];
}