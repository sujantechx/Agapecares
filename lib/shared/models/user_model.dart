import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Represents the authenticated user's data and provides
/// conversion helpers for Firebase and local store usage.
class UserModel extends Equatable {
  final String uid;
  final String phoneNumber;
  final String? name; // Optional name

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      phoneNumber: map['phoneNumber'] as String,
      name: map['name'] as String?,
    );
  }

  // Firestore-friendly (same shape as toMap)
  Map<String, dynamic> toFirestore() => toMap();
  factory UserModel.fromFirestore(Map<String, dynamic> data) =>
      UserModel.fromMap(data);

  // JSON helpers for local storage (e.g., shared_preferences or file)
  String toJson() => json.encode(toMap());
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
    );
  }

  @override
  List<Object?> get props => [uid, phoneNumber, name];
}