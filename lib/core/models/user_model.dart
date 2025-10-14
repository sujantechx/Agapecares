// lib/shared/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? phoneNumber; // named phoneNumber used in codebase
  final String role;
  final String? photoUrl;
  final List<Map<String, dynamic>>? addresses;
  final bool isVerified;
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phoneNumber,
    this.role = 'user',
    this.photoUrl,
    this.addresses,
    this.isVerified = false,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phone'] as String? ?? data['phoneNumber'] as String?,
      role: data['role'] as String? ?? 'user',
      photoUrl: data['photoUrl'] as String?,
      addresses: data['addresses'] != null
          ? List<Map<String, dynamic>>.from(data['addresses'] as List)
          : null,
      isVerified: data['isVerified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber ?? null,
      'role': role,
      'photoUrl': photoUrl,
      'addresses': addresses,
      'isVerified': isVerified,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String? ?? 'user',
      photoUrl: json['photoUrl'] as String?,
      addresses: json['addresses'] != null
          ? List<Map<String, dynamic>>.from(json['addresses'] as List)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: (json['createdAt'] is Timestamp)
          ? json['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'photoUrl': photoUrl,
      'addresses': addresses,
      'isVerified': isVerified,
      'createdAt': createdAt,
    };
  }

  /// Create a UserModel from a [firebase_auth] User instance.
  factory UserModel.fromFirebaseUser(User? user) {
    if (user == null) {
      return UserModel(uid: '', createdAt: Timestamp.now());
    }
    return UserModel(
      uid: user.uid,
      name: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
      createdAt: Timestamp.now(),
    );
  }
}
