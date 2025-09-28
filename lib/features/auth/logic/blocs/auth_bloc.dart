// lib/features/auth/logic/blocs/auth_bloc.dart

import 'package:bloc/bloc.dart';


import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
  }

  /// Handles the event to send an OTP to the user's phone number.
  Future<void> _onSendOtpRequested(
      AuthSendOtpRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    final result = await _authRepository.sendOtp(phoneNumber: event.phoneNumber);
    result.fold(
          (failure) => emit(AuthFailure(failure.message)),
          (_) => emit(AuthCodeSentSuccess()),
    );
  }

  /// Handles the event to verify the OTP submitted by the user.
  Future<void> _onVerifyOtpRequested(
      AuthVerifyOtpRequested event,
      Emitter<AuthState> emit,
      ) async {
    emit(AuthLoading());
    final result = await _authRepository.verifyOtp(otp: event.otp);
    result.fold(
          (failure) => emit(AuthFailure(failure.message)),
          (user) => emit(AuthLoggedIn(user)),
    );
  }
}