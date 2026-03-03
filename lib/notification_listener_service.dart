import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationListenerService {
  static StreamSubscription? _subscription;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Démarrer l'écoute des notifications pour un suiveur
  static Future<void> startListening(String caregiverUid) async {
    print("[NotificationListener] Demarrage ecoute pour: $caregiverUid");

    // Initialiser les notifications locales si pas déjà fait
    await _initializeLocalNotifications();

    // Annuler l'ancienne écoute si elle existe
    await stopListening();

    // Écouter les nouvelles notifications en temps réel
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('caregiverUid', isEqualTo: caregiverUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notif = change.doc.data();
          if (notif != null) {
            await _handleNotification(change.doc.id, notif);
          }
        }
      }
    });
  }

  // Arrêter l'écoute
  static Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    print("[NotificationListener] Ecoute arretee");
  }

  // Initialiser les notifications locales
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Créer canal Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'alzhecare_alerts',
      'Alertes Patient',
      description: 'Notifications pour les alertes patient',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Gérer une notification reçue
  static Future<void> _handleNotification(String notifId, Map<String, dynamic> notif) async {
    print("[NotificationListener] Notification recue: ${notif['notification']?['title']}");

    final notification = notif['notification'] as Map<String, dynamic>?;
    final title = notification?['title'] ?? 'AlzheCare';
    final body = notification?['body'] ?? 'Nouvelle alerte';

    // Afficher notification locale
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'alzhecare_alerts',
      'Alertes Patient',
      channelDescription: 'Notifications pour les alertes patient',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      notifId.hashCode,
      title,
      body,
      details,
    );

    // Marquer comme lue
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    print("[NotificationListener] Notification affichee et marquee comme lue");
  }
}