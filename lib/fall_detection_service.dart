import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';

class FallDetectionService {
  static const int WINDOW_SIZE = 200;
  static const int NUM_SENSORS = 9;

  // --- Seuils calibrés pour vraies chutes uniquement ---
  // UserAccel au repos : ~0 m/s² | marche : 2-4 | course : 5-8 | chute : 15-40
  static const double MIN_MAGNITUDE = 12.0;          // Filtre 1 : pic d'impact minimum
  static const double POST_IMPACT_STILLNESS = 4.0;   // Filtre 2 : immobilité post-chute (moy)
  static const double FALL_THRESHOLD = 0.90;         // Filtre 3 : confiance modèle TFLite
  static const int CONFIRMATION_COUNT = 2;            // 2 fenêtres consécutives validées
  static const int COOLDOWN_SECONDS = 30;             // 30s minimum entre deux alertes
  static const int CONFIRMATION_WINDOW_SECONDS = 8;  // Fenêtre de confirmation
  static const double GRAVITY = 9.81;                // Fallback émulateur

  Interpreter? _interpreter;
  List<double>? _scalerMean;
  List<double>? _scalerScale;

  final List<List<double>> _sensorBuffer = [];
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  StreamSubscription? _userAccelSubscription;

  List<double>? _lastAccel;
  List<double>? _lastGyro;
  List<double>? _lastUserAccel;

  int _samplesSinceLastAnalysis = 0;

  bool isInitialized = false;
  bool _isMonitoring = false;
  bool isPaused = false;

  DateTime? _lastFallDetectionTime;
  int _consecutiveFallCount = 0;
  DateTime? _firstSuspiciousWindowTime;

  Function(bool isFall, double confidence)? onFallDetected;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/fall_detection.tflite');
      final scalerJson = await rootBundle.loadString('assets/models/scaler_params.json');
      final scalerData = json.decode(scalerJson);
      _scalerMean = List<double>.from(scalerData['mean']);
      _scalerScale = List<double>.from(scalerData['scale']);
      isInitialized = true;
      debugPrint('[FallDetection] Service initialisé avec succès');
    } catch (e) {
      debugPrint('[FallDetection] Erreur initialisation: $e');
      rethrow;
    }
  }

  void startMonitoring() {
    if (!isInitialized || _isMonitoring) return;

    _isMonitoring = true;
    _sensorBuffer.clear();
    isPaused = false;
    _lastFallDetectionTime = null;
    _samplesSinceLastAnalysis = 0;

    debugPrint('[FallDetection] Démarrage surveillance');

    _gyroSubscription = gyroscopeEvents.listen((event) {
      _lastGyro = [event.x, event.y, event.z];
    });

    _userAccelSubscription = userAccelerometerEvents.listen((event) {
      _lastUserAccel = [event.x, event.y, event.z];
    });

    _accelSubscription = accelerometerEvents.listen((event) {
      _lastAccel = [event.x, event.y, event.z];
      _addSensorData();
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _userAccelSubscription?.cancel();
    _sensorBuffer.clear();
    debugPrint('[FallDetection] Surveillance arrêtée');
  }

  void pauseDetection() {
    debugPrint('[FallDetection] Pause détection');
    isPaused = true;
  }

  void resumeDetection() {
    debugPrint('[FallDetection] Reprise détection');
    isPaused = false;
    _sensorBuffer.clear();
  }

  void _addSensorData() {
    if (_lastAccel == null || isPaused) return;

    // Zéros par défaut si gyro/userAccel absents (compatibilité émulateur)
    final gyro = _lastGyro ?? [0.0, 0.0, 0.0];
    final userAccel = _lastUserAccel ?? [0.0, 0.0, 0.0];

    final data = [..._lastAccel!, ...gyro, ...userAccel];
    _sensorBuffer.add(data);

    if (_sensorBuffer.length > WINDOW_SIZE + 100) {
      _sensorBuffer.removeAt(0);
    }

    if (_sensorBuffer.length >= WINDOW_SIZE) {
      _samplesSinceLastAnalysis++;
      if (_samplesSinceLastAnalysis >= 50) {
        _analyzeWindow();
        _samplesSinceLastAnalysis = 0;
      }
    }
  }

  void _analyzeWindow() {
    if (isPaused) return;

    // Cooldown post-chute
    if (_lastFallDetectionTime != null &&
        DateTime.now().difference(_lastFallDetectionTime!).inSeconds < COOLDOWN_SECONDS) {
      return;
    }

    // Timeout de la fenêtre de confirmation
    if (_firstSuspiciousWindowTime != null &&
        DateTime.now().difference(_firstSuspiciousWindowTime!).inSeconds > CONFIRMATION_WINDOW_SECONDS) {
      _consecutiveFallCount = 0;
      _firstSuspiciousWindowTime = null;
      debugPrint('[FallDetection] Timeout confirmation, reset');
    }

    try {
      final window = _sensorBuffer.sublist(_sensorBuffer.length - WINDOW_SIZE);

      // ══ FILTRE 1 : Pic d'impact ══════════════════════════════════════════
      // Une vraie chute génère un pic UserAccel > 12 m/s² (marche max ~4, course ~8)
      final peakMag = _calculateMagnitude(window);
      if (peakMag < MIN_MAGNITUDE) return;

      // ══ FILTRE 2 : Immobilité post-impact ═══════════════════════════════
      // Après une chute, la personne est au sol → mouvement faible ensuite
      // Après un ADL brusque (s'asseoir, taper, sauter), le mouvement continue
      final recentSamples = window.sublist(window.length - 20);
      final meanRecentMag = _calculateMeanMagnitude(recentSamples);
      if (meanRecentMag > POST_IMPACT_STILLNESS) {
        debugPrint('[FallDetection] Mouvement continu post-pic (${meanRecentMag.toStringAsFixed(1)} m/s²) → ADL ignoré');
        return;
      }

      // ══ FILTRE 3 : Modèle TFLite ════════════════════════════════════════
      final features = _extractFeatures(window);
      final normalizedFeatures = _normalizeFeatures(features);
      final input = [normalizedFeatures];
      final output = List.filled(1 * 2, 0.0).reshape([1, 2]);
      _interpreter!.run(input, output);

      final probFall = output[0][1];
      debugPrint('[FallDetection] Pic=${peakMag.toStringAsFixed(1)} Still=${meanRecentMag.toStringAsFixed(1)} Fall=${probFall.toStringAsFixed(3)}');

      if (probFall > FALL_THRESHOLD) {
        if (_consecutiveFallCount == 0) _firstSuspiciousWindowTime = DateTime.now();
        _consecutiveFallCount++;
        debugPrint('[FallDetection] Détection #$_consecutiveFallCount/$CONFIRMATION_COUNT');

        if (_consecutiveFallCount >= CONFIRMATION_COUNT) {
          debugPrint('[FallDetection] ✅ CHUTE CONFIRMÉE! Confiance: ${probFall.toStringAsFixed(3)}');
          _lastFallDetectionTime = DateTime.now();
          _consecutiveFallCount = 0;
          _firstSuspiciousWindowTime = null;
          onFallDetected?.call(true, probFall);
        }
      } else {
        if (_consecutiveFallCount > 0) debugPrint('[FallDetection] Modèle non convaincu, reset');
        _consecutiveFallCount = 0;
        _firstSuspiciousWindowTime = null;
      }
    } catch (e) {
      debugPrint('[FallDetection] Erreur analyse: $e');
    }
  }

  /// UserAccel [6,7,8] (sans gravité) en priorité.
  /// Fallback sur |rawAccel| - gravity si UserAccel ≈ 0 (=émulateur).
  double _calculateMagnitude(List<List<double>> window) {
    if (window.isEmpty) return 0;
    double maxUserAccel = 0;
    double maxRawDelta = 0;
    for (var s in window) {
      if (s.length >= 9) {
        final ua = sqrt(s[6]*s[6] + s[7]*s[7] + s[8]*s[8]);
        if (ua > maxUserAccel) maxUserAccel = ua;
        final raw = sqrt(s[0]*s[0] + s[1]*s[1] + s[2]*s[2]);
        final delta = (raw - GRAVITY).abs();
        if (delta > maxRawDelta) maxRawDelta = delta;
      }
    }
    return maxUserAccel > 0.5 ? maxUserAccel : maxRawDelta;
  }

  /// Magnitude MOYENNE des n derniers échantillons (utilisée pour détection d'immobilité).
  double _calculateMeanMagnitude(List<List<double>> window) {
    if (window.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (var s in window) {
      if (s.length >= 9) {
        final ua = sqrt(s[6]*s[6] + s[7]*s[7] + s[8]*s[8]);
        final raw = sqrt(s[0]*s[0] + s[1]*s[1] + s[2]*s[2]);
        final delta = (raw - GRAVITY).abs();
        total += ua > 0.5 ? ua : delta;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  List<double> _extractFeatures(List<List<double>> window) {
    final features = <double>[];
    for (int sensorIdx = 0; sensorIdx < NUM_SENSORS; sensorIdx++) {
      final sensorData = window.map((row) => row[sensorIdx]).toList();
      final mean = _mean(sensorData);
      final std = _std(sensorData);
      final min = sensorData.reduce((a, b) => a < b ? a : b);
      final max = sensorData.reduce((a, b) => a > b ? a : b);
      final range = max - min;
      final q1 = _percentile(sensorData, 25);
      final q3 = _percentile(sensorData, 75);
      features.addAll([mean, std, min, max, range, q1, q3]);
      final fftMagnitude = _fftMagnitude(sensorData);
      final fftMean = _mean(fftMagnitude);
      final fftStd = _std(fftMagnitude);
      final fftMax = fftMagnitude.reduce((a, b) => a > b ? a : b);
      features.addAll([fftMean, fftStd, fftMax]);
    }
    return features;
  }

  List<double> _normalizeFeatures(List<double> features) {
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      normalized.add((features[i] - _scalerMean![i]) / _scalerScale![i]);
    }
    return normalized;
  }

  double _mean(List<double> data) => data.reduce((a, b) => a + b) / data.length;

  double _std(List<double> data) {
    final mean = _mean(data);
    final variance = data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
    return sqrt(variance);
  }

  double _percentile(List<double> data, double p) {
    final sorted = List<double>.from(data)..sort();
    final index = (p / 100) * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  List<double> _fftMagnitude(List<double> data) {
    final magnitude = <double>[];
    final n = data.length;
    for (int k = 0; k < n ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int t = 0; t < n; t++) {
        final angle = -2 * pi * k * t / n;
        real += data[t] * cos(angle);
        imag += data[t] * sin(angle);
      }
      magnitude.add(sqrt(real * real + imag * imag));
    }
    return magnitude;
  }

  void dispose() {
    stopMonitoring();
    _interpreter?.close();
    isInitialized = false;
  }
}