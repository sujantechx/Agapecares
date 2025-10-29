// lib/features/common_auth/data/repositories/auth_repository.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _firebaseUserSubscription;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _firebaseUserSubscription =
        _firebaseAuth.authStateChanges().listen((firebaseUser) {
          _onFirebaseUserChanged(firebaseUser);
        });
  }

  final _userController = StreamController<UserModel?>.broadcast();

  Stream<UserModel?> get user => _userController.stream;

  /// Private method to handle changes from Firebase Auth.
  Future<void> _onFirebaseUserChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _userController.add(null);
      return;
    }

    // --- NEW FIX: CHECK FOR NEW USER ---
    final isEmailLogin = firebaseUser.providerData.any((p) => p.providerId == 'password');

    // Check if this is a brand new user (creation time == last sign in time)
    final creation = firebaseUser.metadata.creationTime?.millisecondsSinceEpoch ?? 0;
    final lastSignIn = firebaseUser.metadata.lastSignInTime?.millisecondsSinceEpoch ?? 0;
    // Use a 2-second buffer just to be safe
    final isNewUser = (lastSignIn - creation).abs() < 2000;

    // NOTE: Changed behavior: Do NOT block sign-in for email/password users whose
    // email is not verified. The previous logic signed out such users. We now allow
    // existing email/password users to remain signed in regardless of emailVerified.
    // (Keeping the isEmailLogin/isNewUser checks only for possible future use.)

    // If it's a new user, Google user, or verified email user, proceed...
    UserModel? userModel;
    int attempts = 0;
    while (attempts < 3) {
      try {
        userModel = await _fetchUserModel(firebaseUser.uid);
        break;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          attempts++;
          await Future.delayed(Duration(milliseconds: 300 * attempts));
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }

    if (userModel != null) {
      _userController.add(userModel);
    } else {
      // Profile doc is missing. Try to create it.
      try {
        await createProfileFromPending(firebaseUser);
        userModel = await _fetchUserModel(firebaseUser.uid);
        _userController.add(userModel);
      } catch (e) {
        // If creation fails, emit a minimal model
        final minimal = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email,
          phoneNumber: firebaseUser.phoneNumber,
          phoneProvided: (firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty),
          phoneVerified: false,
          phoneVerifiedAt: null,
          role: UserRole.user,
          createdAt: Timestamp.now(),
        );
        _userController.add(minimal);
      }
    }
  }

  Future<UserModel?> _fetchUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data() ?? <String, dynamic>{};
      final rawRole = (data['role'] as String?) ?? '';
      final roleStr = rawRole.trim().toLowerCase();

      UserRole role = UserRole.user;
      if (roleStr.contains('admin')) {
        role = UserRole.admin;
      } else if (roleStr.contains('worker')) {
        role = UserRole.worker;
      }

      final String? phoneFromData = data['phone'] as String?;
      final bool phoneProvided = (data['phoneProvided'] as bool?) ??
          (phoneFromData != null && phoneFromData.isNotEmpty);

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
        phoneProvided: phoneProvided,
        phoneVerified: (data['phoneVerified'] as bool?) ?? false,
        phoneVerifiedAt: data['phoneVerifiedAt'] as Timestamp?,
      );
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      print('Error fetching user model: $e');
      return null;
    }
  }

  /// Signs in a user with their email and password.
  Future<void> signInWithEmail(
      {required String email, required String password}) async {

    try {
      // 1. Sign in the user
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);

      final firebaseUser = userCredential.user;

      // NOTE: Changed behavior: Do NOT require email verification to allow sign-in.
      // Only ensure that a user object was returned (i.e. email/password matched).
      if (firebaseUser == null) {
        throw FirebaseAuthException(
            code: 'user-not-found', message: 'Failed to sign in user.');
      }

      // Ensure profile exists (create from pending if necessary).
      try {
        await createProfileFromPending(firebaseUser);
      } catch (_) {}

    } catch (e) {
      rethrow;
    }
  }

  /// Registers a new user with email and password.
  /// This function now handles errors correctly.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    User? firebaseUser; // Define user in outer scope for cleanup
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);

      firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('User creation failed.');
      }

      // --- START OF CRITICAL SECTION ---
      // We are now logged in as the new user.
      // We MUST create the profile and send the email.

      // 1. Create the Firestore user profile
      try {
        final userDoc = _firestore.collection('users').doc(firebaseUser.uid);
        final newUser = UserModel(
          uid: firebaseUser.uid,
          name: name,
          email: email,
          phoneNumber: phone,
          phoneProvided: phone.isNotEmpty,
          phoneVerified: false,
          phoneVerifiedAt: null,
          role: role,
          createdAt: Timestamp.now(), // Use client time as fallback
        );
        final data = newUser.toFirestore();
        data['createdAt'] = FieldValue.serverTimestamp(); // Let server set final time
        await userDoc.set(data);
      } catch (e) {
        // This is the PERMISSION_DENIED error from the logs.
        print('Error: failed to create users/ profile at registration: $e');
        // Re-throw to trigger cleanup
        throw Exception('Failed to create user profile. Check Firestore rules.');
      }

      // 2. Send verification email
      try {
        await firebaseUser.sendEmailVerification();
      } catch (e) {
        print('Error: failed to send verification email: $e');
        // Re-throw to trigger cleanup
        throw Exception('Failed to send verification email.');
      }
      // --- END OF CRITICAL SECTION ---

      // 3. Success! Sign the user out so they must verify.
      await _firebaseAuth.signOut();

    } catch (e) {
      // This catch block handles:
      // 1. 'email-already-in-use' from createUserWithEmailAndPassword
      // 2. Firestore profile creation failure
      // 3. Send email failure

      print('Registration failed: $e');

      // Cleanup: If the auth user was created but the profile/email failed,
      // we must delete the auth user to avoid a broken state.
      if (firebaseUser != null) {
        await firebaseUser.delete().catchError((deleteError) {
          print('Failed to clean up orphaned auth user: $deleteError');
        });
      }
      // Sign out just in case
      await _firebaseAuth.signOut().catchError((_) {});

      // Re-throw the original error so the BLoC can catch it
      rethrow;
    }
  }

  /// Signs in using Google Sign-In.
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw Exception('Google sign-in aborted by user');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
          credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception(
          'Google sign-in failed: no user returned');

      final usersRef = _firestore.collection('users').doc(firebaseUser.uid);
      final doc = await usersRef.get();
      if (!doc.exists) {
        final newUser = UserModel(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName,
          email: firebaseUser.email,
          phoneNumber: firebaseUser.phoneNumber,
          phoneProvided: (firebaseUser.phoneNumber != null &&
              firebaseUser.phoneNumber!.isNotEmpty),
          phoneVerified: false,
          phoneVerifiedAt: null,
          role: UserRole.user,
          createdAt: Timestamp.now(),
        );
        final map = newUser.toFirestore();
        map['createdAt'] = FieldValue.serverTimestamp();
        await usersRef.set(map);
      }
    } catch (e) {
      try {
        await _firebaseAuth.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {}
      rethrow;
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // --- Other methods from your file (no changes needed) ---

  Future<void> createProfileFromPending(User user) async {
    final pendingRef = _firestore.collection('pending_profiles').doc(user.uid);
    final pendingSnap = await pendingRef.get();
    final usersRef = _firestore.collection('users').doc(user.uid);
    final existing = await usersRef.get();
    if (existing.exists) {
      if (pendingSnap.exists) await pendingRef.delete().catchError((_) {});
      return;
    }
    if (pendingSnap.exists) {
      final data = pendingSnap.data()!;
      final newUser = UserModel(
        uid: user.uid,
        name: data['name'] as String? ?? user.displayName ?? '',
        email: data['email'] as String? ?? user.email,
        phoneNumber: data['phone'] as String? ?? user.phoneNumber,
        phoneProvided: (data['phoneProvided'] as bool?) ?? false,
        phoneVerified: (data['phoneVerified'] as bool?) ?? false,
        phoneVerifiedAt: data['phoneVerifiedAt'] as Timestamp?,
        role: (data['role'] is String && (data['role'] as String).toLowerCase().contains('worker'))
            ? UserRole.worker
            : (data['role'] is String && (data['role'] as String).toLowerCase().contains('admin') ? UserRole.admin : UserRole.user),
        createdAt: Timestamp.now(),
      );
      final map = newUser.toFirestore();
      map['createdAt'] = FieldValue.serverTimestamp();
      await usersRef.set(map);
      await pendingRef.delete().catchError((_) {});
      return;
    }
    final minimal = UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email,
      phoneNumber: user.phoneNumber,
      phoneProvided: (user.phoneNumber != null && user.phoneNumber!.isNotEmpty),
      phoneVerified: false,
      phoneVerifiedAt: null,
      role: UserRole.user,
      createdAt: Timestamp.now(),
    );
    final map = minimal.toFirestore();
    map['createdAt'] = FieldValue.serverTimestamp();
    await usersRef.set(map);
  }

  Future<String> sendPhoneVerification(String phoneNumber) async {
    final completer = Completer<String>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {},
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

  Future<void> verifyPhoneCode(
      {required String verificationId, required String smsCode, String? name, String? email, UserRole? role}) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    final user = userCredential.user;
    if (user != null) {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await _firebaseAuth.signOut();
        throw Exception(
            'No user profile found for this phone number. Please register using Email/Password.');
      }
    }
  }

  Future<void> registerWithEmailAndLinkPhone({
    required String verificationId,
    required String smsCode,
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) throw Exception('Failed to create email user');
    try {
      await firebaseUser.linkWithCredential(credential);
    } catch (e) {
      await firebaseUser.delete().catchError((_) {});
      rethrow;
    }
    final userModel = UserModel(
      uid: firebaseUser.uid,
      name: name,
      email: email,
      phoneNumber: phone,
      phoneProvided: phone.isNotEmpty,
      phoneVerified: true,
      phoneVerifiedAt: Timestamp.now(),
      role: role,
      createdAt: Timestamp.now(),
    );
    try {
      final data = userModel.toFirestore();
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(firebaseUser.uid).set(data);
    } catch (e) {
      await firebaseUser.delete().catchError((_) {});
      rethrow;
    }
    try {
      await firebaseUser.sendEmailVerification();
    } catch (e) {
      print('Failed to send verification email: $e');
    }
    await _firebaseAuth.signOut();
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await GoogleSignIn().signOut().catchError((_) {});
  }

  void dispose() {
    _firebaseUserSubscription?.cancel();
    _userController.close();
  }
}