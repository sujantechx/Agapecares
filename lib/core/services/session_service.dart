// ...existing code...

// New file: lib/core/services/session_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Simple session service that stores a serialized UserModel in SharedPreferences.
/// - init() must be called before first use (main() already does this).
/// - saveUser() persists the user, getUser() returns a cached UserModel if present.
class SessionService {
  static const String _kUserKey = 'session_user_v1';

  SharedPreferences? _prefs;

  /// Initialize the underlying SharedPreferences instance.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Persist the user model to local storage.
  Future<void> saveUser(UserModel user) async {
    if (_prefs == null) await init();
    final Map<String, dynamic> map = {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'phoneNumber': user.phoneNumber,
      'photoUrl': user.photoUrl,
      'role': user.role.name,
      'addresses': user.addresses,
      // store createdAt as millis since epoch
      'createdAt': user.createdAt.millisecondsSinceEpoch,
    };
    await _prefs!.setString(_kUserKey, jsonEncode(map));
  }

  /// Return the stored UserModel or null if none.
  UserModel? getUser() {
    if (_prefs == null) return null;
    final s = _prefs!.getString(_kUserKey);
    if (s == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(s) as Map<String, dynamic>;
      final roleStr = (map['role'] as String?) ?? '';
      // Normalize role string so values like 'Admin' or 'ADMIN' map correctly.
      final normalized = roleStr.trim().toLowerCase();
      final role = UserRole.values.firstWhere((e) => e.name.toLowerCase() == normalized, orElse: () => UserRole.user);
      final createdAtMillis = map['createdAt'] as int?;
      final createdAt = createdAtMillis != null ? Timestamp.fromMillisecondsSinceEpoch(createdAtMillis) : Timestamp.now();
      final addressesDynamic = map['addresses'];
      List<Map<String, dynamic>>? addresses;
      if (addressesDynamic is List) {
        addresses = addressesDynamic.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return UserModel(
        uid: map['uid'] as String,
        name: map['name'] as String?,
        email: map['email'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        photoUrl: map['photoUrl'] as String?,
        role: role,
        addresses: addresses,
        createdAt: createdAt,
      );
    } catch (e) {
      // If parsing fails, clear the stored value to avoid repeated errors.
      clear();
      return null;
    }
  }

  /// Returns true when a user session exists locally.
  bool isLoggedIn() {
    if (_prefs == null) return false;
    return _prefs!.containsKey(_kUserKey);
  }

  /// Remove stored user session.
  Future<void> clear() async {
    if (_prefs == null) await init();
    await _prefs!.remove(_kUserKey);
  }
}

// ...existing code...
