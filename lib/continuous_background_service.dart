import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class ContinuousBackgroundService {
  static Timer? _positionTimer;
  static bool _isRunning = false;
  static StreamSubscription<Position>? _positionSubscription;

  static const int _updateIntervalSeconds = 180;

  static Future<void> startForPatient() async {
    if (_isRunning) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[ContinuousBgService] Pas d\'utilisateur connecté');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = userDoc.data()?['role'];
    if (role != 'patient') {
      debugPrint('[ContinuousBgService] Utilisateur n\'est pas un patient');
      return;
    }

    _isRunning = true;
    _startPositionTracking();

    debugPrint('[ContinuousBgService] Service démarré pour patient');
  }

  static Future<void> _startPositionTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[ContinuousBgService] GPS désactivé');
      _isRunning = false;
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        debugPrint('[ContinuousBgService] Permission GPS refusée');
        _isRunning = false;
        return;
      }
    }

    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(seconds: _updateIntervalSeconds),
      (_) => _updatePosition(),
    );

    await _updatePosition();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen(
      (position) => _processPosition(position),
      onError: (e) => debugPrint('[ContinuousBgService] Erreur stream GPS: $e'),
    );
  }

  static Future<void> _updatePosition() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      await _processPosition(position);
    } catch (e) {
      debugPrint('[ContinuousBgService] Erreur mise à jour position: $e');
    }
  }

  static Future<void> _processPosition(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastPosition': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });

      await _checkGeofence(user.uid, position);

      debugPrint('[ContinuousBgService] Position: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('[ContinuousBgService] Erreur traitement position: $e');
    }
  }

  static Future<void> _checkGeofence(String uid, Position position) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = userDoc.data();
      if (data == null) return;

      final homeLocation = data['homeLocation'];
      if (homeLocation == null) return;

      final homeLat = homeLocation['latitude'] as double;
      final homeLng = homeLocation['longitude'] as double;
      final safeZoneRadius = (data['safeZoneRadius'] ?? 300) as int;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        homeLat,
        homeLng,
      );

      final wasInZone = data['inZone'] as bool? ?? true;
      final isOutside = distance > safeZoneRadius;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'inZone': !isOutside,
        'lastDistance': distance.toInt(),
      });

      if (isOutside && wasInZone) {
        await _sendGeofenceAlert(uid, position, distance, data);
      }
    } catch (e) {
      debugPrint('[ContinuousBgService] Erreur géofencing: $e');
    }
  }

  static Future<void> _sendGeofenceAlert(
    String uid,
    Position position,
    double distance,
    Map<String, dynamic> userData,
  ) async {
    try {
      final recentAlerts = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alerts')
          .where('type', isEqualTo: 'perdu')
          .where('automatic', isEqualTo: true)
          .get();

      for (var doc in recentAlerts.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inMinutes < 30) {
            return;
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('alerts')
          .add({
        'type': 'perdu',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'automatic': true,
        'distance': distance.toInt(),
        'createdBy': 'continuous_bg',
      });

      await FCMService.sendGeofenceAlert(
        patientUid: uid,
        distance: distance.toInt(),
        latitude: position.latitude,
        longitude: position.longitude,
      );

      debugPrint('[ContinuousBgService] Alerte géofence envoyée via FCM');
    } catch (e) {
      debugPrint('[ContinuousBgService] Erreur alerte géofence: $e');
    }
  }

  static void stop() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isRunning = false;
    debugPrint('[ContinuousBgService] Service arrêté');
  }

  static bool get isRunning => _isRunning;
}