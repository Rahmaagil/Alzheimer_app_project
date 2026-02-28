// user_session_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gère la session utilisateur pour les tâches en arrière-plan
/// Nécessaire car FirebaseAuth ne fonctionne pas toujours en background
class UserSessionManager {

  static const String _keyUid = 'user_uid';
  static const String _keyRole = 'user_role';

  /// Sauvegarder la session au login
  static Future<void> saveSession(User user, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, user.uid);
    await prefs.setString(_keyRole, role);
    print("Session sauvegardée: ${user.uid}");
  }

  /// Récupérer l'UID (fonctionne en background)
  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  /// Récupérer le rôle
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  /// Vérifier si l'utilisateur est patient
  static Future<bool> isPatient() async {
    final role = await getRole();
    return role == 'patient';
  }

  /// Effacer la session au logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUid);
    await prefs.remove(_keyRole);
    print("Session effacée");
  }
}