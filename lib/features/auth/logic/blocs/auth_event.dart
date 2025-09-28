// lib/features/auth/logic/blocs/auth_event.dart


import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

/// Event triggered when the user requests to send an OTP.
class AuthSendOtpRequested extends AuthEvent {
  final String phoneNumber;
  const AuthSendOtpRequested(this.phoneNumber);
  @override
  List<Object> get props => [phoneNumber];
}

/// Event triggered when the user submits the OTP for verification.
class AuthVerifyOtpRequested extends AuthEvent {
  final String otp;
  const AuthVerifyOtpRequested(this.otp);
  @override
  List<Object> get props => [otp];
}