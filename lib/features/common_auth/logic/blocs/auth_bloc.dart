// lib/features/common_auth/logic/bloc/auth_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for exceptions
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

  // Convert various exception types into user-friendly messages suitable for UI SnackBars.
  String _friendlyErrorMessage(Object error) {
    try {
      if (error is PlatformException) {
        // Google Sign-In on Android may surface a PlatformException with
        // code 'sign_in_failed' and message containing 'ApiException: 10' when
        // the SHA fingerprint or OAuth client is misconfigured. Map that to
        // a helpful message for the user/developer.
        if (error.code == 'sign_in_failed' || (error.message ?? '').contains('ApiException: 10')) {
          return 'Google sign-in failed due to app configuration. Make sure your Android package name and SHA-1/SH A-256 fingerprints are added in the Firebase console and that your google-services.json is up to date.';
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
            return 'This email is already in use. Try signing in or resetting your password.';
          case 'invalid-email':
            return 'The email address entered is invalid.';
          case 'network-request-failed':
            return 'Network error. Check your internet connection and try again.';
          case 'too-many-requests':
            return 'Too many attempts. Please wait and try again later.';
          case 'account-exists-with-different-credential':
            return 'An account already exists with a different sign-in method for this email.';
          case 'credential-already-in-use':
            return 'This credential is already linked to another account.';
          case 'email-not-verified':
            return 'Please verify your email address. Check your inbox for the verification email.';
          default:
            return error.message ?? 'Authentication error. Please try again.';
        }
      }
      if (error is FirebaseException) {
        return error.message ?? error.toString();
      }
      // Fallback for other exception types
      return error.toString();
    } catch (e) {
      return 'An unexpected error occurred.';
    }
  }

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
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<AuthMarkPhoneVerifiedRequested>(_onMarkPhoneVerifiedRequested);
    on<AuthRegisterWithPhoneOtpRequested>(_onRegisterWithPhoneOtpRequested);
    // SMS provider integration removed; no handler for SMS request events.
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
      // Ensure the email is verified before proceeding. If not verified, sign out and ask user to verify.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || !(firebaseUser.emailVerified)) {
        // Attempt to send another verification email if possible and then sign out.
        try {
          if (firebaseUser != null) await firebaseUser.sendEmailVerification();
        } catch (_) {}
        await FirebaseAuth.instance.signOut();
        emit(AuthEmailVerificationSent(email: event.email));
        return;
      }
      // If verified, ensure any pending profile is created.
      try {
        await _authRepository.createProfileFromPending(firebaseUser);
      } catch (_) {}
      // The user stream will emit a new value, and _onAuthStatusChanged will handle the state change.
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
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
      // Registration now requires email verification. Inform UI to tell user to check their email.
      emit(AuthEmailVerificationSent(email: event.email));
      // The user stream will emit a new value when/if the user verifies and signs in.
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
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
      // The user stream will emit a new value, and _onAuthStatusChanged will handle the state change.
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _onSignOutRequested(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    // The user stream will emit null, and _onAuthStatusChanged will handle the state change.
  }

  Future<void> _onSignInWithGoogleRequested(AuthSignInWithGoogleRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithGoogle();
      // The user stream will emit the new user and AuthStatusChanged will handle state update.
    } on FirebaseAuthException catch (e) {
      // Special-case when repository indicates the Google account's email is not verified
      if (e.code == 'email-not-verified') {
        emit(AuthEmailVerificationSent(email: e.message));
        return;
      }
      emit(AuthFailure(_friendlyErrorMessage(e)));
    } catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
    }
  }

  Future<void> _onMarkPhoneVerifiedRequested(AuthMarkPhoneVerifiedRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.markPhoneVerified(uid: event.uid);
      // Fetch updated user model via repository's stream; we can optimistically try to fetch now
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        try {
          await _authRepository.createProfileFromPending(firebaseUser);
        } catch (_) {}
      }
      // The repository will emit the updated user model on its stream, triggering AuthStatusChanged.
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
      // After linking and creating the user doc, repository sends verification email and signs out.
      emit(AuthEmailVerificationSent(email: event.email));
    } on FirebaseAuthException catch (e) {
      emit(AuthFailure(_friendlyErrorMessage(e)));
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