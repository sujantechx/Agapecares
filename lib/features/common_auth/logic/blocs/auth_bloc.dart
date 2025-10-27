// lib/features/common_auth/logic/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/session_service.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SessionService? _sessionService;
  StreamSubscription<UserModel?>? _userSubscription;

  String _friendlyErrorMessage(Object error) {
    try {
      if (error is PlatformException) {
        if (error.code == 'sign_in_failed' || (error.message ?? '').contains('ApiException: 10')) {
          return 'Google sign-in failed. Check app configuration in Firebase console (SHA-1).';
        }
        return error.message ?? error.toString();
      }

      if (error is FirebaseAuthException) {
        switch (error.code) {
          case 'user-not-found':
            return 'No account found with the provided email.';
          case 'wrong-password':
            return 'Incorrect password. Please try again.';
          case 'email-already-in-use':
            return 'This email is already in use. Try signing in.';
          case 'invalid-email':
            return 'The email address entered is invalid.';
          case 'network-request-failed':
            return 'Network error. Check your internet connection.';
          case 'too-many-requests':
            return 'Too many attempts. Please wait and try again later.';
          case 'account-exists-with-different-credential':
            return 'An account already exists with a different sign-in method for this email.';
        // This is our custom error from the repository
          case 'email-not-verified':
            return 'Please verify your email. Check your inbox for the verification email.';
          default:
            return error.message ?? 'Authentication error. Please try again.';
        }
      }
      // This will catch the "No user profile found" error from the repo
      return error.toString();
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

  AuthBloc({required AuthRepository authRepository, SessionService? sessionService})
      : _authRepository = authRepository,
        _sessionService = sessionService,
        super(AuthInitial()) {

    _userSubscription = _authRepository.user.listen((user) {
      add(AuthStatusChanged(user));
    });

    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLoginWithEmailRequested>(_onLoginWithEmailRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<AuthRegisterWithPhoneOtpRequested>(_onRegisterWithPhoneOtpRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
  }

  Future<void> _onPasswordResetRequested(AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.sendPasswordResetEmail(email: event.email);
      emit(AuthPasswordResetSent(email: event.email));
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  void _onAuthStatusChanged(AuthStatusChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      if (kDebugMode) {
        debugPrint('AuthBloc: Authenticated user role=${event.user!.role} uid=${event.user!.uid}');
      }
      try {
        _sessionService?.saveUser(event.user!);
      } catch (e) {
        if (kDebugMode) debugPrint('Session save failed: $e');
      }
      emit(Authenticated(event.user!));
    } else {
      try {
        _sessionService?.clear();
      } catch (_) {}
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginWithEmailRequested(AuthLoginWithEmailRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // The repository now handles the verification check
      await _authRepository.signInWithEmail(email: event.email, password: event.password);
      // Success is handled by the _onAuthStatusChanged listener
    } on FirebaseAuthException catch (e) {
      // This catches 'email-not-verified' as well as 'wrong-password', etc.
      if (e.code == 'email-not-verified') {
        // Emit a special state so the UI can show the "Resend" dialog
        emit(AuthEmailVerificationSent(email: event.email));
      } else {
        // Emit a general failure for other errors
        emit(AuthFailure(_friendlyErrorMessage(e)));
      }
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
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
      // The repo sends email and signs out.
      // Emit state to tell UI to pop and show "check your email" message.
      emit(AuthEmailVerificationSent(email: event.email));
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _onSendOtpRequested(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final verificationId = await _authRepository.sendPhoneVerification(event.phoneNumber);
      emit(AuthOtpSent(verificationId));
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
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
      // Success is handled by the _onAuthStatusChanged listener
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    // Success is handled by the _onAuthStatusChanged listener
  }

  Future<void> _onSignInWithGoogleRequested(AuthSignInWithGoogleRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithGoogle();
      // Success is handled by the _onAuthStatusChanged listener
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _onRegisterWithPhoneOtpRequested(AuthRegisterWithPhoneOtpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.registerWithEmailAndLinkPhone(
        verificationId: event.verificationId,
        smsCode: event.otp,
        email: event.email,
        password: event.password,
        name: event.name,
        phone: event.phone,
        role: event.role,
      );
      // The repo sends verification email and signs out.
      emit(AuthEmailVerificationSent(email: event.email));
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}