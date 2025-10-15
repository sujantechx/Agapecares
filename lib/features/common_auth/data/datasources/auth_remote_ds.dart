// lib/features/auth/data/datasources/auth_remote_ds.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agapecares/core/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phoneNumber);
  Future<UserModel> verifyOtp(String otp);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  String? _verificationId;

  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  @override
  Future<void> sendOtp(String phoneNumber) async {
    final completer = Completer<void>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Auto-sign in if possible
      },
      verificationFailed: (FirebaseAuthException e) {
        completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        completer.complete();
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
    return completer.future;
  }

  @override
  Future<UserModel> verifyOtp(String otp) async {
    if (_verificationId == null) {
      throw Exception('OTP was not sent. Please try again.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw Exception('Login failed, user not found.');
    }

    // Fetch user profile from Firestore to get their role
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      // This case can happen if a user verifies but didn't complete registration
      // Build a basic UserModel from the Firebase User (models must not be changed).
      return UserModel(
        uid: user.uid,
        name: user.displayName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        photoUrl: user.photoURL,
        role: UserRole.user, // Default to 'user' for phone sign-ups
        addresses: null,
        createdAt: Timestamp.now(),
      );
    }
    return UserModel.fromFirestore(doc);
  }
}