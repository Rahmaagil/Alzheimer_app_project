import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthMethod { none, biometric }

class AppSecurityService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _authMethodKey = 'auth_method';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  static bool _isBiometricAvailable = false;
  static AuthMethod _currentMethod = AuthMethod.none;
  static Timer? _sessionTimer;
  static DateTime? _lastActivityTime;
  static int _sessionTimeoutMinutes = 5;
  static Function()? _onSessionExpired;

  static Future<void> initialize({
    int sessionTimeoutMinutes = 5,
    Function()? onSessionExpired,
  }) async {
    _sessionTimeoutMinutes = sessionTimeoutMinutes;
    _onSessionExpired = onSessionExpired;
    
    try {
      _isBiometricAvailable = await _localAuth.canCheckBiometrics;
      final savedMethod = await _secureStorage.read(key: _authMethodKey);
      if (savedMethod != null) {
        _currentMethod = AuthMethod.values.firstWhere(
          (e) => e.name == savedMethod,
          orElse: () => AuthMethod.none,
        );
      }
    } catch (e) {
      debugPrint('[Security] Erreur init: $e');
    }
  }

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> enableBiometric(bool enable) async {
    try {
      if (enable) {
        final canAuth = await _localAuth.canCheckBiometrics;
        if (!canAuth) return false;
        
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authentifiez-vous pour activer la biométrie',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        
        if (!authenticated) return false;
        
        await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
        await _secureStorage.write(key: _authMethodKey, value: AuthMethod.biometric.name);
        _currentMethod = AuthMethod.biometric;
      } else {
        await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
        await _secureStorage.write(key: _authMethodKey, value: AuthMethod.none.name);
        _currentMethod = AuthMethod.none;
      }
      return true;
    } catch (e) {
      debugPrint('[Security] Erreur activation biométrie: $e');
      return false;
    }
  }

  static Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authentifiez-vous pour accéder à l\'application',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('[Security] Erreur authentification biométrique: $e');
      return false;
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  static AuthMethod get currentAuthMethod => _currentMethod;

  static void startSessionMonitoring() {
    _lastActivityTime = DateTime.now();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkSessionTimeout();
    });
  }

  static void resetSessionTimer() {
    _lastActivityTime = DateTime.now();
  }

  static void _checkSessionTimeout() {
    if (_lastActivityTime == null || _currentMethod == AuthMethod.none) return;
    
    final diff = DateTime.now().difference(_lastActivityTime!);
    if (diff.inMinutes >= _sessionTimeoutMinutes) {
      _onSessionExpired?.call();
      stopSessionMonitoring();
    }
  }

  static void stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  static Future<void> lockApp() async {
    stopSessionMonitoring();
    await FirebaseAuth.instance.signOut();
  }
}
