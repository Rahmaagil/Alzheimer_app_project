import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class GeofencingService {

  static const String _taskName = "geofence_check";

  /// INITIALISATION
  static Future<void> initialize() async {
    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: true,
    );
    print("[GeofencingService] Service initialisé");
  }

  /// DÉMARRER TRACKING
  static Future<void> startTracking({int intervalMinutes = 15}) async {
    await Workmanager().registerPeriodicTask(
      "geofence-task",
      _taskName,
      frequency: Duration(minutes: intervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    print("[GeofencingService] Tracking démarré ($intervalMinutes min)");
  }

  /// STOP TRACKING
  static Future<void> stopTracking() async {
    await Workmanager().cancelAll();
    print("[GeofencingService] Tracking arrêté");
  }

  /// TEST MANUEL
  static Future<void> checkNow() async {
    await _checkGeofenceForCurrentUser();
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {

    WidgetsFlutterBinding.ensureInitialized();

    await NotificationService.initialize();

    try {
      await _checkGeofenceForCurrentUser();
      return Future.value(true);
    } catch (e) {
      print("[Background] Erreur: $e");
      return Future.value(false);
    }
  });
}

Future<void> _checkGeofenceForCurrentUser() async {

  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('user_uid');
  final role = prefs.getString('user_role');

  if (uid == null || role != 'patient') {
    print("[Geofencing] Aucun patient connecté");
    return;
  }

  /// 1️⃣ Vérifier si GPS activé
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("[Geofencing] GPS désactivé");
    return;
  }

  /// 2️⃣ Vérifier permission
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    print("[Geofencing] Permission refusée");
    return;
  }

  /// 3️⃣ Récupérer position
  Position position;

  try {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium, // Batterie optimisée
      timeLimit: const Duration(seconds: 15),
    );
  } catch (e) {
    print("[Geofencing] Erreur GPS: $e");
    return;
  }

  await _updatePosition(uid, position);
  await _checkGeofence(uid, position);
}

Future<void> _updatePosition(String uid, Position position) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'lastPosition': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });
  } catch (e) {
    print("[Geofencing] Erreur update position: $e");
  }
}

Future<void> _checkGeofence(String uid, Position currentPosition) async {
  try {

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      print("[Geofencing] Document utilisateur inexistant");
      return;
    }

    final data = doc.data();
    if (data == null) return;

    final homeLocation = data['homeLocation'];
    if (homeLocation == null) {
      print("[Geofencing] Domicile non configuré");
      return;
    }

    final homeLat = homeLocation['latitude'] as double;
    final homeLng = homeLocation['longitude'] as double;

    final safeZoneRadius = (data['safeZoneRadius'] ?? 300) as int;

    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      homeLat,
      homeLng,
    );

    bool isOutside = distance > safeZoneRadius;

    /// Mettre à jour statut dans Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'inZone': !isOutside,
      'lastDistance': distance.toInt(),
    });

    if (isOutside) {
      await _createAlert(uid, currentPosition, distance);
    }

  } catch (e) {
    print("[Geofencing] Erreur vérification: $e");
  }
}

Future<void> _createAlert(String uid, Position position, double distance) async {
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
          print("[Geofencing] Alerte récente existante");
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
      'createdBy': 'geofencing',
    });


    print("[Geofencing] ALERTE CRÉÉE");

    await NotificationService.showGeofenceAlert(
      distance: distance.toInt(),
    );

  } catch (e) {
    print("[Geofencing] Erreur création alerte: $e");
  }
}
