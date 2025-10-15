// lib/features/common_auth/data/repositories/auth_repository.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/user_model.dart';

/// The central repository for handling all authentication-related operations.
/// It abstracts the data sources (Firebase Auth, Firestore) and provides a clean
/// API for the AuthBloc to use. It is the single source of truth for the
/// current user's authentication state.
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _firebaseUserSubscription;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    // When the repository is created, start listening to Firebase Auth state changes.
    _firebaseUserSubscription = _firebaseAuth.authStateChanges().listen((firebaseUser) {
      _onFirebaseUserChanged(firebaseUser);
    });
  }

  /// A stream that emits the current `UserModel` when the auth state changes.
  /// Emits `null` if the user is signed out. This is the core of the reactive auth system.
  final _userController = StreamController<UserModel?>.broadcast();
  Stream<UserModel?> get user => _userController.stream;

  /// Private method to handle changes from Firebase Auth.
  /// When a user logs in or out, this fetches their Firestore data and adds it to our stream.
  Future<void> _onFirebaseUserChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _userController.add(null);
    } else {
      final userModel = await _fetchUserModel(firebaseUser.uid);
      _userController.add(userModel);
    }
  }

  /// Fetches the user's profile from the `users` collection in Firestore.
  Future<UserModel?> _fetchUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null; // Should ideally not happen for a logged-in user

      // Build the UserModel here with resilient parsing of the 'role' field so
      // that values like 'Admin', 'ADMIN', or 'admin' are treated the same.
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Normalize role string and map to enum safely without changing the model file.
      final rawRole = (data['role'] as String?) ?? '';
      final roleStr = rawRole.trim().toLowerCase();
      UserRole role = UserRole.user;
      try {
        role = UserRole.values.firstWhere((e) => e.name.toLowerCase() == roleStr);
      } catch (_) {
        role = UserRole.user;
      }

      return UserModel(
        uid: doc.id,
        name: data['name'] as String?,
        email: data['email'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        photoUrl: data['photoUrl'] as String?,
        role: role,
        addresses: data['addresses'] != null
            ? List<Map<String, dynamic>>.from(data['addresses'] as List)
            : null,
        createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      );
    } catch (e) {
      // Handle potential errors, like network issues or permissions
      print('Error fetching user model: $e');
      return null;
    }
  }

  /// Signs in a user with their email and password.
  Future<void> signInWithEmail({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Registers a new user with email and password and creates their document in Firestore.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw Exception('User creation failed.');
    }
    // Create the user document in Firestore.
    final userModel = UserModel(
      uid: firebaseUser.uid,
      name: name,
      email: email,
      phoneNumber: phone,
      role: role,
      createdAt: Timestamp.now(),
    );
    await _firestore.collection('users').doc(firebaseUser.uid).set(userModel.toFirestore());
  }

  /// Sends a verification OTP to the provided phone number.
  /// Returns the `verificationId` needed to verify the OTP later.
  Future<String> sendPhoneVerification(String phoneNumber) async {
    final completer = Completer<String>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {
        // This is for auto-verification, which we can handle if needed
      },
      verificationFailed: (FirebaseAuthException e) {
        completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
    return completer.future;
  }

  /// Verifies the OTP and signs the user in.
  /// Also ensures a user document exists in Firestore.
  Future<void> verifyPhoneCode({required String verificationId, required String smsCode}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // After sign-in, ensure a corresponding user document exists.
    // This is crucial for users who sign in for the first time via phone.
    final user = userCredential.user;
    if (user != null) {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        final newUser = UserModel(
          uid: user.uid,
          phoneNumber: user.phoneNumber,
          role: UserRole.user, // Default role for new phone sign-ups
          createdAt: Timestamp.now(),
        );
        await docRef.set(newUser.toFirestore());
      }
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Cleans up the stream subscription when the repository is no longer needed.
  void dispose() {
    _firebaseUserSubscription?.cancel();
    _userController.close();
  }
}