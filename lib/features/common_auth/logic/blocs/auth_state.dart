

// lib/features/auth/logic/blocs/auth_state.dart


import 'package:equatable/equatable.dart';

import '../../../../shared/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object> get props => [];
}

/// The initial state of the authentication flow.
class AuthInitial extends AuthState {}

/// State indicating that an authentication process is ongoing (e.g., API call).
class AuthLoading extends AuthState {}

/// State indicating that the OTP was successfully sent.
class AuthCodeSentSuccess extends AuthState {}

/// State indicating the user has successfully logged in.
class AuthLoggedIn extends AuthState {
  final UserModel user;
  const AuthLoggedIn(this.user);
  @override
  List<Object> get props => [user];
}

/// State indicating that an error occurred during authentication.
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object> get props => [message];
}