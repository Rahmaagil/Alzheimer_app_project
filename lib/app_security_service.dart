import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthMethod { none, biometric, pin }

class AppSecurityService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _pinKey = 'user_pin';
  static const String _authMethodKey = 'auth_method';
  static const String _sessionTimeoutKey = 'session_timeout_minutes';
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

  static Future<bool> hasSetupPIN() async {
    final pin = await _secureStorage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<bool> setupPIN(String pin) async {
    if (pin.length < 4 || pin.length > 6) return false;
    
    try {
      await _secureStorage.write(key: _pinKey, value: pin);
      await _secureStorage.write(key: _authMethodKey, value: AuthMethod.pin.name);
      _currentMethod = AuthMethod.pin;
      return true;
    } catch (e) {
      debugPrint('[Security] Erreur setup PIN: $e');
      return false;
    }
  }

  static Future<bool> verifyPIN(String pin) async {
    try {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin == pin;
    } catch (e) {
      debugPrint('[Security] Erreur vérification PIN: $e');
      return false;
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

  static Future<void> changePIN(String oldPIN, String newPIN) async {
    final isValid = await verifyPIN(oldPIN);
    if (!isValid) throw Exception('PIN actuel incorrect');
    
    if (newPIN.length < 4 || newPIN.length > 6) {
      throw Exception('Le PIN doit contenir 4 à 6 chiffres');
    }
    
    await _secureStorage.write(key: _pinKey, value: newPIN);
  }

  static Future<void> removePIN() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.write(key: _authMethodKey, value: AuthMethod.none.name);
    _currentMethod = AuthMethod.none;
  }

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

class SecurityWrapper extends StatefulWidget {
  final Widget child;
  final Widget lockScreen;
  
  const SecurityWrapper({
    super.key,
    required this.child,
    required this.lockScreen,
  });

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isLocked = true;
  bool _securityEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSecurity();
  }

  Future<void> _initSecurity() async {
    final method = await AppSecurityService.currentAuthMethod;
    if (method != AuthMethod.none) {
      setState(() {
        _securityEnabled = true;
        _isLocked = true;
      });
      _showLockScreen();
    } else {
      setState(() => _isLocked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _securityEnabled) {
      setState(() => _isLocked = true);
    }
  }

  void _showLockScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.lockScreen, fullscreenDialog: true),
    );
  }

  void _unlock() {
    setState(() => _isLocked = false);
    AppSecurityService.startSessionMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  
  const LockScreen({super.key, required this.onUnlock});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final List<String> _pin = [];
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (await AppSecurityService.isBiometricEnabled()) {
      final auth = await AppSecurityService.authenticateWithBiometric();
      if (auth) widget.onUnlock();
    }
  }

  void _addDigit(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin.add(digit);
        _error = null;
      });
      
      if (_pin.length >= 4) {
        _verifyPIN();
      }
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() => _pin.removeLast());
    }
  }

  Future<void> _verifyPIN() async {
    setState(() => _isLoading = true);
    
    final pin = _pin.join();
    final isValid = await AppSecurityService.verifyPIN(pin);
    
    setState(() => _isLoading = false);
    
    if (isValid) {
      widget.onUnlock();
    } else {
      setState(() {
        _error = 'PIN incorrect';
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Application verrouillée',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entrez votre code PIN',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled 
                          ? const Color(0xFF4A90E2) 
                          : Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 40),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  ...['1','2','3','4','5','6','7','8','9','','0','del'].map((d) {
                    if (d.isEmpty) return const SizedBox(width: 72, height: 72);
                    if (d == 'del') {
                      return _buildKeyButton(
                        child: const Icon(Icons.backspace_outlined, color: Color(0xFF2E5AAC)),
                        onTap: _removeDigit,
                      );
                    }
                    return _buildKeyButton(
                      child: Text(d, style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5AAC),
                      )),
                      onTap: () => _addDigit(d),
                    );
                  }),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint, color: Color(0xFF4A90E2)),
                label: const Text('Utiliser la biométrie', 
                    style: TextStyle(color: Color(0xFF4A90E2))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}