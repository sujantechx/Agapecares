// lib/shared/models/user_model.dart

import 'package:equatable/equatable.dart';

/// Represents the authenticated user's data.
class UserModel extends Equatable {
  final String uid;
  final String phoneNumber;
  final String? name; // Optional name

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.name,
  });

  @override
  List<Object?> get props => [uid, phoneNumber, name];
}