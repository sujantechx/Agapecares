import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SessionService {
  static const String _kUserJson = 'user_json';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveUser(UserModel user) async {
    final SharedPreferences prefs = _requirePrefs();
    // Ensure we store a JSON string
    final Map<String, dynamic> map = user.toJson();
    final String jsonStr = jsonEncode(map);
    await prefs.setString(_kUserJson, jsonStr);
  }

  UserModel? getUser() {
    final SharedPreferences prefs = _requirePrefs();
    final String? jsonStr = prefs.getString(_kUserJson);
    if (jsonStr == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  bool isLoggedIn() {
    final SharedPreferences prefs = _requirePrefs();
    return prefs.containsKey(_kUserJson);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = _requirePrefs();
    await prefs.remove(_kUserJson);
  }

  SharedPreferences _requirePrefs() {
    if (_prefs == null) throw Exception('SessionService not initialized. Call init() first.');
    return _prefs!;
  }
}
