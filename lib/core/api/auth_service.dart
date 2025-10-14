import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agapecares/core/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Email/password registration creating a Firestore user doc with role
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String role, // 'user' | 'worker' | 'admin'
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document
    final userDoc = _firestore.collection('users').doc(cred.user!.uid);
    final model = UserModel(
      uid: cred.user!.uid,
      email: email,
      name: displayName,
      role: role,
      phoneNumber: cred.user!.phoneNumber,
    );
    await userDoc.set(model.toFirestore());

    // Update display name on Firebase user
    await cred.user!.updateDisplayName(displayName);

    return cred;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Phone auth: send code and verify. This keeps simple helper methods
  Future<String> sendPhoneVerification(String phone,
      {required void Function(PhoneAuthCredential) onVerified,
      required void Function(FirebaseAuthException) onFailed,
      required void Function(String, int?) onCodeSent}) async {
    String verificationId = '';
    await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) {
          onVerified(credential);
        },
        verificationFailed: (e) {
          onFailed(e);
        },
        codeSent: (id, resendToken) {
          verificationId = id;
          onCodeSent(id, resendToken);
        },
        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
        });
    return verificationId;
  }

  Future<UserCredential> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    return await _auth.signInWithCredential(credential);
  }

  // Fetch user profile from Firestore
  Future<UserModel?> fetchUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // Ensure there's a Firestore user doc for a newly phone-authenticated user
  Future<void> ensureUserDocForUid({
    required String uid,
    String? name,
    String? phone,
    String role = 'user',
  }) async {
    final ref = _firestore.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final model = UserModel(uid: uid, email: null, name: name, role: role, phoneNumber: phone);
      await ref.set(model.toFirestore());
    }
  }
}
