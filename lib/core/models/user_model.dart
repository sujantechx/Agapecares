// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum to define user roles for type safety.
enum UserRole { user, worker, admin }

/// Represents a user document in the `users` collection in Firestore.
/// This is the single source of truth for a person's identity and role.
class UserModel extends Equatable {
  /// The unique identifier from Firebase Authentication, same as the document ID.
  final String uid;

  /// The user's full display name.
  final String? name;

  /// The user's primary email address.
  final String? email;

  /// The user's phone number.
  final String? phoneNumber;

  /// Whether the phone number was provided at registration time.
  final bool phoneProvided;

  /// Whether the phone number has been verified (via SMS provider).
  final bool phoneVerified;

  /// When the phone was verified (server timestamp) or null if not verified.
  final Timestamp? phoneVerifiedAt;

  /// The URL for the user's profile picture.
  final String? photoUrl;

  /// The role of the user, which controls their access permissions.
  final UserRole role;

  /// A list of saved addresses for the user. Each address is a map.
  final List<Map<String, dynamic>>? addresses;

  /// Timestamp of when the user account was created.
  final Timestamp createdAt;

  const UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phoneNumber,
    this.phoneProvided = false,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.photoUrl,
    required this.role,
    this.addresses,
    required this.createdAt,
  });

  /// Creates a `UserModel` instance from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String?,
      email: data['email'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      phoneProvided: (data['phoneProvided'] as bool?) ?? (data['phoneNumber'] != null),
      phoneVerified: (data['phoneVerified'] as bool?) ?? false,
      phoneVerifiedAt: data['phoneVerifiedAt'] as Timestamp?,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.values.firstWhere(
            (e) => e.name == (data['role'] as String?),
        orElse: () => UserRole.user, // Default to 'user' if role is missing or invalid
      ),
      addresses: data['addresses'] != null
          ? List<Map<String, dynamic>>.from(data['addresses'] as List)
          : null,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts this `UserModel` instance into a map for storing in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'phoneProvided': phoneProvided,
      'phoneVerified': phoneVerified,
      'phoneVerifiedAt': phoneVerifiedAt,
      'photoUrl': photoUrl,
      'role': role.name, // Store the enum as a string
      'addresses': addresses,
      'createdAt': createdAt,
    };
  }

  /// Creates a copy of this user with updated fields.
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phoneNumber,
    bool? phoneProvided,
    bool? phoneVerified,
    Timestamp? phoneVerifiedAt,
    String? photoUrl,
    UserRole? role,
    List<Map<String, dynamic>>? addresses,
    Timestamp? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneProvided: phoneProvided ?? this.phoneProvided,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      addresses: addresses ?? this.addresses,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [uid, name, email, phoneNumber, phoneProvided, phoneVerified, phoneVerifiedAt, photoUrl, role, addresses, createdAt];
}