import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alzhecare/face_camera_screen.dart';
import 'package:alzhecare/patient_home_screen.dart';
import 'package:alzhecare/caregiver_home_screen.dart';
import 'package:alzhecare/patient_onboarding_screen.dart';
import 'package:alzhecare/app_notifications.dart';
import 'package:alzhecare/app_security_service.dart';
import 'theme.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF4A90E2)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          AppDecorationWidgets.buildDecoCircles(),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.face, color: Colors.white, size: 60),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Identifiez-vous avec votre visage\npour accéder à l\'application',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 48),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    _isLoading
                        ? const CircularProgressIndicator(color: Color(0xFF4A90E2))
                        : Column(
                            children: [
                              // Face recognition button
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _loginWithFace,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A90E2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.face, color: Colors.white, size: 28),
                                      SizedBox(width: 12),
                                      Text(
                                        'Me connecter par visage',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Fingerprint button
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _loginWithFingerprint,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF64B5F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.fingerprint, color: Colors.white, size: 28),
                                      SizedBox(width: 12),
                                      Text(
                                        'Me connecter par empreinte',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _showEmailLogin,
                      child: const Text(
                        'Problèmes de connexion ?',
                        style: TextStyle(color: Color(0xFF4A90E2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithFace() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => const FaceCameraScreen(isRegistrationMode: false),
        ),
      );

      if (result != null && result['recognized'] == true) {
        final recognizedName = result['name'] as String?;
        await _completeLogin(recognizedName);
      } else {
        setState(() {
          _error = 'Visage non reconnu. Veuillez réessayer.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithFingerprint() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isBiometricAvailable = await AppSecurityService.isBiometricAvailable();
      if (!isBiometricAvailable) {
        setState(() {
          _error = 'Empreinte digitale non disponible sur cet appareil';
          _isLoading = false;
        });
        return;
      }

      final authenticated = await AppSecurityService.authenticateWithBiometric();
      
      if (authenticated) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists) {
            setState(() {
              _error = 'Compte non trouvé';
              _isLoading = false;
            });
            return;
          }

          final onboardingComplete = userDoc['onboardingComplete'] ?? false;

          if (!onboardingComplete) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PatientOnboardingScreen()),
              );
            }
            return;
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
            );
          }
        } else {
          setState(() {
            _error = 'Erreur de connexion';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Empreinte non reconnue';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _completeLogin(String? recognizedName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Erreur de connexion';
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _error = 'Compte non trouvé';
          _isLoading = false;
        });
        return;
      }

      final onboardingComplete = userDoc['onboardingComplete'] ?? false;

      if (!onboardingComplete) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PatientOnboardingScreen()),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion: $e';
        _isLoading = false;
      });
    }
  }

  void _showEmailLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    );
  }
}

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      final role = userDoc['role'] as String? ?? 'patient';

      if (mounted) {
        if (role == 'patient') {
          final onboardingComplete = userDoc['onboardingComplete'] ?? false;
          if (!onboardingComplete) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PatientOnboardingScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
            );
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CaregiverHomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erreur de connexion';
      if (e.code == 'user-not-found') {
        message = 'Aucun compte trouvé';
      } else if (e.code == 'wrong-password') {
        message = 'Mot de passe incorrect';
      }

      if (mounted) {
        AppNotifications.showError(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF4A90E2)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connexion',
          style: TextStyle(color: Color(0xFF4A90E2), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Veuillez entrer votre email';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'votre@email.com',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4A90E2)),
                          filled: true,
                          fillColor: const Color(0xFFF3F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Mot de passe',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Veuillez entrer votre mot de passe';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4A90E2)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF4A90E2),
                            ),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Se connecter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}