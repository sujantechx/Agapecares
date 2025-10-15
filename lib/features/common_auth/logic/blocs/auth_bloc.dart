// lib/features/common_auth/logic/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for exceptions
import 'package:flutter/foundation.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/session_service.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';



class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SessionService? _sessionService;
  StreamSubscription<UserModel?>? _userSubscription;

  /// [sessionService] is optional to allow lightweight test setups.
  AuthBloc({required AuthRepository authRepository, SessionService? sessionService})
      : _authRepository = authRepository,
        _sessionService = sessionService,
        super(AuthInitial()) {
    // Listen to user changes from the repository
    _userSubscription = _authRepository.user.listen((user) {
      add(AuthStatusChanged(user));
    });

    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLoginWithEmailRequested>(_onLoginWithEmailRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  void _onAuthStatusChanged(AuthStatusChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      if (kDebugMode) {
        debugPrint('AuthBloc: Authenticated user role=${event.user!.role} uid=${event.user!.uid}');
      }
      // Persist the authenticated user to local session cache to keep
      // in-sync role/identity across app restarts and lightweight flows
      // where the SessionService is available.
      try {
        _sessionService?.saveUser(event.user!);
      } catch (e) {
        if (kDebugMode) debugPrint('Session save failed: $e');
      }
      emit(Authenticated(event.user!));
    } else {
      // Clear cached session when the user signs out.
      try {
        _sessionService?.clear();
      } catch (_) {}
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginWithEmailRequested(AuthLoginWithEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithEmail(email: event.email, password: event.password);
      // The user stream will emit a new value, and _onAuthStatusChanged will handle the state change.
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'Login Failed'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.registerWithEmail(
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
        role: event.role,
      );
      // The user stream will emit a new value, and _onAuthStatusChanged will handle the state change.
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(e.message ?? 'Registration Failed'));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onSendOtpRequested(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final verificationId = await _authRepository.sendPhoneVerification(event.phoneNumber);
      emit(AuthOtpSent(verificationId));
    } catch (e) {
      emit(AuthFailure('Failed to send OTP: ${e.toString()}'));
    }
  }

  Future<void> _onVerifyOtpRequested(AuthVerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.verifyPhoneCode(
        verificationId: event.verificationId,
        smsCode: event.otp,
        name: event.name,
        email: event.email,
        role: event.role,
      );
      // The user stream will emit a new value, and _onAuthStatusChanged will handle the state change.
    } catch (e) {
      emit(AuthFailure('Failed to verify OTP: ${e.toString()}'));
    }
  }

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    // The user stream will emit null, and _onAuthStatusChanged will handle the state change.
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}