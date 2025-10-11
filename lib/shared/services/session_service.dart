import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SessionService {
  static const _kUserJson = 'user_json';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = _requirePrefs();
    // Store the JSON string produced by UserModel.toJson().
    await prefs.setString(_kUserJson, user.toJson());
  }

  UserModel? getUser() {
    final prefs = _requirePrefs();
    final jsonStr = prefs.getString(_kUserJson);
    if (jsonStr == null) return null;
    try {
      // UserModel.fromJson expects a JSON string.
      return UserModel.fromJson(jsonStr);
    } catch (_) {
      return null;
    }
  }

  bool isLoggedIn() {
    final prefs = _requirePrefs();
    return prefs.containsKey(_kUserJson);
  }

  Future<void> clear() async {
    final prefs = _requirePrefs();
    await prefs.remove(_kUserJson);
  }

  SharedPreferences _requirePrefs() {
    if (_prefs == null) throw Exception('SessionService not initialized. Call init() first.');
    return _prefs!;
  }
}
