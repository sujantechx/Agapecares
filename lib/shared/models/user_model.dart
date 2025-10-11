import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Represents the authenticated user's data and provides
/// conversion helpers for Firebase and local store usage.
class UserModel extends Equatable {
  final String uid;
  final String phoneNumber;
  final String? name; // Optional name
  final String? email; // Optional email

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.name,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'email': email,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const UserModel(uid: '', phoneNumber: '', name: null, email: null);
    }

    return UserModel(
      uid: map['uid'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
    );
  }

  // Firestore-friendly (same shape as toMap)
  Map<String, dynamic> toFirestore() => toMap();
  factory UserModel.fromFirestore(Map<String, dynamic> data) =>
      UserModel.fromMap(data);

  // JSON helpers for local storage (e.g., shared_preferences or file)
  String toJson() => json.encode(toMap());
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>?);

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    String? email,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [uid, phoneNumber, name, email];
}