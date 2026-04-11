import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'fall_detection_service.dart';
import 'fcm_service.dart';
import 'package:alzhecare/main.dart' show navigatorKey;

class FallDetectionBackgroundService {
  static FallDetectionService? _fallService;
  static bool _isRunning = false;
  static bool _isProcessingFall = false;
  static BuildContext? _appContext;

  static bool get isRunning => _isRunning;

  static void setContext(BuildContext context) {
    _appContext = context;
    debugPrint('[BgFallDetection] Context defini');
  }

  static Future<void> startForPatient() async {
    debugPrint('[BgFallDetection] Tentative demarrage...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[BgFallDetection] Pas d\'utilisateur connecte');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = userDoc.data()?['role'];
      if (role != 'patient') {
        debugPrint('[BgFallDetection] Utilisateur n\'est pas un patient, role: $role');
        return;
      }

      if (_isRunning) {
        debugPrint('[BgFallDetection] Service deja en cours');
        return;
      }

      _fallService = FallDetectionService();
      await _fallService!.initialize();

      _fallService!.onFallDetected = (isFall, confidence) {
        debugPrint('[BgFallDetection] Callback recu: isFall=$isFall, confidence=$confidence');
        if (isFall) {
          _showFallConfirmationDialog(confidence);
        }
      };

      _fallService!.startMonitoring();
      _isRunning = true;
      debugPrint('[BgFallDetection] Service demarre avec succes');
    } catch (e) {
      debugPrint('[BgFallDetection] Erreur demarrage: $e');
      _isRunning = false;
    }
  }

  static void _showFallConfirmationDialog(double confidence) {
    // Verrou : empêcher l'empilement de plusieurs dialogs
    if (_isProcessingFall) {
      debugPrint('[BgFallDetection] Déjà en traitement, dialog ignoré');
      return;
    }
    _isProcessingFall = true;
    _fallService?.pauseDetection();

    // Utilise navigatorKey.currentContext en fallback si _appContext est invalide
    final context = (_appContext != null && _appContext!.mounted)
        ? _appContext!
        : navigatorKey.currentContext;

    if (context == null) {
      debugPrint('[BgFallDetection] Pas de context disponible, envoi alerte automatique');
      _sendAutomaticFallAlert(confidence);
      return;
    }

    debugPrint('[BgFallDetection] Affichage dialog confirmation');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FallConfirmationDialog(
        confidence: confidence,
        onConfirm: (needHelp) async {
          Navigator.of(dialogContext).pop();
          if (needHelp) {
            debugPrint('[BgFallDetection] Patient demande aide');
            await _sendAutomaticFallAlert(confidence);
          } else {
            debugPrint('[BgFallDetection] Patient va bien');
            _isProcessingFall = false;
            _fallService?.resumeDetection();
            final ctx = (_appContext != null && _appContext!.mounted)
                ? _appContext!
                : navigatorKey.currentContext;
            if (ctx != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Vous allez bien'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }

  static Future<void> _sendAutomaticFallAlert(double confidence) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      debugPrint('[BgFallDetection] Envoi alerte automatique, confidence=$confidence');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedCaregiversRaw = userDoc.data()?['linkedCaregivers'];

      List<String> linkedCaregivers = [];
      if (linkedCaregiversRaw is List) {
        linkedCaregivers = linkedCaregiversRaw
            .where((id) => id != null && id.toString().isNotEmpty)
            .map((id) => id.toString())
            .toList();
      }

      if (linkedCaregivers.isEmpty) {
        debugPrint('[BgFallDetection] Aucun caregiver lie');
        return;
      }

      GeoPoint? location;
      double? latitude, longitude;

      try {
        final locationDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('locations')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (locationDoc.docs.isNotEmpty) {
          location = locationDoc.docs.first.data()['location'] as GeoPoint?;
          if (location != null) {
            latitude = location.latitude;
            longitude = location.longitude;
          }
        }
      } catch (e) {
        debugPrint('[BgFallDetection] Erreur position: $e');
      }

      try {
        debugPrint('[BgFallDetection] Envoi notification chute via FCM');

        await FCMService.sendFallAlert(
          patientUid: user.uid,
          latitude: latitude,
          longitude: longitude,
        );
        debugPrint('[BgFallDetection] Notification chute envoyee');
      } catch (e) {
        debugPrint('[BgFallDetection] Erreur envoi notification: $e');
      }
    } catch (e) {
      debugPrint('[BgFallDetection] Erreur generale: $e');
    }

    // Toujours relâcher le verrou et reprendre la détection après l'envoi,
    // peu importe l'état du context - sinon le service reste bloqué indéfiniment.
    await Future.delayed(const Duration(seconds: 15));
    _isProcessingFall = false;
    _fallService?.resumeDetection();
  }

  /// À utiliser uniquement en mode debug pour tester le dialog sur émulateur
  static void simulateFallForTest() {
    debugPrint('[BgFallDetection] ⚠️ SIMULATION CHUTE (DEBUG)');
    _showFallConfirmationDialog(0.99);
  }

  static void stop() {
    _fallService?.stopMonitoring();
    _fallService?.dispose();
    _fallService = null;
    _isRunning = false;
    debugPrint('[BgFallDetection] Service arrete');
  }
}

class _FallConfirmationDialog extends StatefulWidget {
  final double confidence;
  final Function(bool needHelp) onConfirm;

  const _FallConfirmationDialog({
    required this.confidence,
    required this.onConfirm,
  });

  @override
  State<_FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<_FallConfirmationDialog> {
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[FallDialog] Ouverture, confidence=${widget.confidence}');
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hasResponded) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _respond(true);
      }
    });
  }

  void _respond(bool needHelp) {
    if (_hasResponded) return;
    debugPrint('[FallDialog] Reponse: needHelp=$needHelp');
    setState(() => _hasResponded = true);
    _timer?.cancel();
    widget.onConfirm(needHelp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFFFFEBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5F6D).withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Chute Detectee!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _hasResponded ? 'Traitement...' : '$_secondsRemaining secondes',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Allez-vous bien?',
                style: TextStyle(fontSize: 20, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _hasResponded ? null : () => _respond(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasResponded ? Colors.grey : const Color(0xFF66BB6A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _hasResponded ? 0 : 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 28,
                        color: _hasResponded ? Colors.grey.shade600 : Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'JE VAIS BIEN',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _hasResponded ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _hasResponded ? null : () => _respond(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasResponded ? Colors.grey : const Color(0xFFFF5F6D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _hasResponded ? 0 : 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sos,
                        size: 28,
                        color: _hasResponded ? Colors.grey.shade600 : Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "J'AI BESOIN D'AIDE",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _hasResponded ? Colors.grey.shade600 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}