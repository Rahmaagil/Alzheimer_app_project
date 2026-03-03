import 'package:shared_preferences/shared_preferences.dart';

class UserSessionManager {

  // Sauvegarder la session
  static Future<void> saveSession(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    await prefs.setString('user_role', role);
  }

  // Récupérer l'UID
  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_uid');
  }

  // Récupérer le rôle
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // Effacer la session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('user_role');
  }
}