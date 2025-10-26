// lib/features/common_auth/data/repositories/auth_repository.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  })
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    // When the repository is created, start listening to Firebase Auth state changes.
    _firebaseUserSubscription =
        _firebaseAuth.authStateChanges().listen((firebaseUser) {
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

      // If the user is an admin, ensure a marker document exists at /admins/{uid}.
      // This helps Firestore security rules detect admin users without requiring
      // custom claims or manual console changes. It's a best-effort client-side
      // creation: if the write fails due to rules, we log and continue.
      try {
        if (userModel != null && userModel.role == UserRole.admin) {
          final adminDoc = _firestore.collection('admins').doc(
              firebaseUser.uid);
          final adminSnap = await adminDoc.get();
          if (!adminSnap.exists) {
            await adminDoc.set({
              'uid': firebaseUser.uid,
              'email': userModel.email,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (e) {
        // Log but don't break auth flow; permission errors may occur if rules prevent creation.
        print('Could not ensure admin marker doc: $e');
      }
    }
  }

  /// Fetches the user's profile from the `users` collection in Firestore.
  Future<UserModel?> _fetchUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists)
        return null; // Should ideally not happen for a logged-in user

      // Build the UserModel here with resilient parsing of the 'role' field so
      // that values like 'Admin', 'ADMIN', or 'admin' are treated the same.
      final data = doc.data() ?? <String, dynamic>{};

      // Normalize role string and map to enum safely without changing the model file.
      final rawRole = (data['role'] as String?) ?? '';
      final roleStr = rawRole.trim().toLowerCase();
      // Be resilient to various role formats saved in Firestore like:
      // - 'admin' / 'ADMIN'
      // - 'UserRole.admin' (when some code stored the enum's toString())
      // - 'role: "UserRole.admin"' etc.
      UserRole role = UserRole.user;
      if (roleStr.contains('admin')) {
        role = UserRole.admin;
      } else if (roleStr.contains('worker')) {
        role = UserRole.worker;
      } else if (roleStr.contains('user')) {
        role = UserRole.user;
      } else {
        // Fallback: try exact match against enum names
        try {
          role = UserRole.values.firstWhere((e) =>
          e.name.toLowerCase() == roleStr);
        } catch (_) {
          role = UserRole.user;
        }
      }

      // Safely parse phoneProvided from Firestore data.
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
      );
    } catch (e) {
      // Handle potential errors, like network issues or permissions
      print('Error fetching user model: $e');
      return null;
    }
  }

  /// Signs in a user with their email and password.
  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  /// Registers a new user with email and password and sends a verification email.
  /// We DO NOT create the Firestore profile here. The app requires the user
  /// to verify their email first; profile creation occurs after verification
  /// when the user signs in with a verified email.
  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    // Create the auth user
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('User creation failed.');
      }

      // Send email verification and sign the user out. The profile will be created
      // only after the user verifies their email and signs in with a verified account.
      try {
        // Store pending profile so we can create a full profile after email verification
        try {
          await _firestore
              .collection('pending_profiles')
              .doc(firebaseUser.uid)
              .set({
            'name': name,
            'phone': phone,
            'phoneProvided': (phone.isNotEmpty),
            'phoneVerified': false,
            'role': role.name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Log but continue: preference for user to verify by email
          print('Failed to store pending profile: $e');
        }
        await firebaseUser.sendEmailVerification();
      } catch (e) {
        // If sending verification fails, attempt to delete the created auth user to avoid orphaned accounts.
        try {
          await firebaseUser.delete();
        } catch (_) {
          await _firebaseAuth.signOut();
        }
        rethrow;
      }

      // Sign out so the app returns to an unauthenticated state until verification completes.
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Create a Firestore profile for a user that has already verified their email.
  /// This should be called after a verified user signs in (for example, in the AuthBloc
  /// after confirming emailVerified == true). If the profile already exists, this method is a no-op.
  Future<void> createProfileForVerifiedUser({
    required User user,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) return; // already created

    final newUser = UserModel(
      uid: user.uid,
      name: name,
      email: user.email,
      phoneNumber: phone,
      phoneProvided: phone.isNotEmpty,
      phoneVerified: false,
      phoneVerifiedAt: null,
      role: role,
      createdAt: Timestamp.now(),
    );
    final data = newUser.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    // Phone is stored; SMS provider integration is intentionally disabled.
  }

  /// Create a Firestore profile for a user from the pending_profiles collection
  /// if it exists. This is idempotent and safe to call after sign-in of a verified user.
  Future<void> createProfileFromPending(User user) async {
    final pendingRef = _firestore.collection('pending_profiles').doc(user.uid);
    final pendingSnap = await pendingRef.get();
    final usersRef = _firestore.collection('users').doc(user.uid);
    final existing = await usersRef.get();
    if (existing.exists) {
      // profile already exists
      if (pendingSnap.exists) {
        // optional cleanup
        try {
          await pendingRef.delete();
        } catch (_) {}
      }
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
        role: (data['role'] is String &&
            (data['role'] as String).toLowerCase().contains('worker'))
            ? UserRole.worker
            : (data['role'] is String &&
            (data['role'] as String).toLowerCase().contains('admin') ? UserRole
            .admin : UserRole.user),
        createdAt: Timestamp.now(),
      );
      final map = newUser.toFirestore();
      map['createdAt'] = FieldValue.serverTimestamp();
      await usersRef.set(map);
      // Phone verification via SMS provider is intentionally not created here.
      // Phone numbers are stored and can be verified later via an external flow.
      try {
        await pendingRef.delete();
      } catch (_) {}
      // emit created user
      final fetched = await _fetchUserModel(user.uid);
      if (fetched != null) _userController.add(fetched);
      return;
    }

    // No pending profile; fall back to creating a minimal profile from Firebase user info.
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
    // Emit the created minimal user model
    final fetched = await _fetchUserModel(user.uid);
    if (fetched != null) _userController.add(fetched);
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
  /// By default this will NOT create a user document for first-time phone sign-ins.
  /// Set [createIfMissing] to `true` when you explicitly want to create the profile
  /// (for example, when calling from a phone-based registration flow).
  Future<void> verifyPhoneCode(
      {required String verificationId, required String smsCode, String? name, String? email, UserRole? role, bool createIfMissing = false}) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    // After sign-in, ensure a corresponding user document exists.
    final user = userCredential.user;
    if (user != null) {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        if (!createIfMissing) {
          // We intentionally do NOT create a user document here. Many apps treat phone
          // login as a sign-in method only; creation should be done through explicit
          // registration (email flow) to control role assignment. Sign the user out
          // and surface a clear error to the caller.
          await _firebaseAuth.signOut();
          throw Exception(
              'No user profile found for this phone number. Please register using Email/Password.');
        }

        final newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phoneNumber: user.phoneNumber,
          phoneProvided: (user.phoneNumber != null &&
              user.phoneNumber!.isNotEmpty),
          phoneVerified: false,
          phoneVerifiedAt: null,
          role: role ?? UserRole.user,
          // Default role for new phone sign-ups
          createdAt: Timestamp.now(),
        );
        try {
          final data = newUser.toFirestore();
          data['createdAt'] = FieldValue.serverTimestamp();
          await docRef.set(data);

          // If the role is admin, create admin marker as well
          if (newUser.role == UserRole.admin) {
            try {
              await _firestore.collection('admins').doc(user.uid).set({
                'createdAt': FieldValue.serverTimestamp(),
                'uid': user.uid,
                'phone': user.phoneNumber,
              });
            } catch (e) {
              print('Failed to create admin marker for phone registration: $e');
            }
          }

          // Emit created user model to avoid race with auth state listener
          final fetched = await _fetchUserModel(user.uid);
          if (fetched != null) {
            _userController.add(fetched);
          } else {
            _userController.add(newUser);
          }
        } catch (e) {
          // If write fails, sign out to avoid partial state.
          await _firebaseAuth.signOut();
          rethrow;
        }
      } else {
        // If profile exists, emit it so listeners get the parsed model.
        final fetched = await _fetchUserModel(user.uid);
        _userController.add(fetched);
      }
    }
  }

  /// Register email/password and link a phone credential created from verificationId/smsCode.
  /// Creates the user document in `users` with a server timestamp and sends verification email.
  Future<void> registerWithEmailAndLinkPhone({
    required String verificationId,
    required String smsCode,
    required String email,
    required String password,
    required String name,
    required String phone,
    required UserRole role,
  }) async {
    // Build phone credential
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);

    // Create email user
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) throw Exception('Failed to create email user');

    try {
      // Link phone credential
      await firebaseUser.linkWithCredential(credential);
    } catch (e) {
      // If linking fails, cleanup and rethrow
      try {
        await firebaseUser.delete();
      } catch (_) {
        await _firebaseAuth.signOut();
      }
      rethrow;
    }

    // Create user document in Firestore with server timestamp
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
      // If write fails, cleanup auth user to avoid orphaned account
      try {
        await firebaseUser.delete();
      } catch (_) {
        await _firebaseAuth.signOut();
      }
      rethrow;
    }

    // Send verification email
    try {
      await firebaseUser.sendEmailVerification();
    } catch (e) {
      // Log but do not fail registration. The user can request a resend.
      print('Failed to send verification email: $e');
    }

    // Sign out until user verifies email
    await _firebaseAuth.signOut();
  }

  /// Signs in using Google Sign-In. If a Firestore profile does not exist for the
  /// authenticated user, create one with a server timestamp. This method is
  /// idempotent and will simply sign in an existing user.
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

      // Enforce email verification for Google sign-ins as well. Although most
      // Google accounts come with verified emails, we treat unverified emails
      // uniformly: send verification, sign out, and ask the UI to notify the user.
      if (!(firebaseUser.emailVerified)) {
        try {
          await firebaseUser.sendEmailVerification();
        } catch (_) {}
        // Keep Firebase and Google sign-in state clean
        try {
          await _firebaseAuth.signOut();
          await GoogleSignIn().signOut();
        } catch (_) {}
        // Throw a FirebaseAuthException with a specific code so the bloc can
        // show the 'check your email' flow consistently.
        throw FirebaseAuthException(
            code: 'email-not-verified', message: firebaseUser.email ?? '');
      }

      // Ensure a corresponding Firestore profile exists. If not, create a minimal one.
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
        // No SMS provider integration: phone remains unverified until manual/provider integration.

        // Emit created user model to avoid race with auth state listener
        final fetched = await _fetchUserModel(firebaseUser.uid);
        if (fetched != null) {
          _userController.add(fetched);
        } else {
          _userController.add(newUser);
        }
      } else {
        final fetched = await _fetchUserModel(firebaseUser.uid);
        if (fetched != null) _userController.add(fetched);
      }
    } catch (e) {
      // On error make sure to sign out from Firebase to keep app state consistent
      try {
        await _firebaseAuth.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {}
      rethrow;
    }
  }

  /// Marks the phone as verified for [uid] (if null, current Firebase user is used).
  Future<void> markPhoneVerified({String? uid}) async {
    final targetUid = uid ?? _firebaseAuth.currentUser?.uid;
    if (targetUid == null) throw Exception('No user to mark phone verified');
    final docRef = _firestore.collection('users').doc(targetUid);
    // Update phoneVerified and set a server timestamp for phoneVerifiedAt
    await docRef.update({
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
      'phoneProvided': true,
    });
    // Emit updated user model
    final fetched = await _fetchUserModel(targetUid);
    if (fetched != null) _userController.add(fetched);
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