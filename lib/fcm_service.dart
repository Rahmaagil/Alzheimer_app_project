import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Handler pour notifications en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("[FCM Background] Message recu: ${message.notification?.title}");
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Initialiser FCM
  static Future<void> initialize() async {
    // Demander permission (iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] Permission accordee');
    } else {
      print('[FCM] Permission refusee');
      return;
    }

    // Configuration notifications locales
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('[FCM] Notification cliquee: ${details.payload}');
      },
    );

    // Créer canal Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'alzhecare_channel',
      'Alertes AlzheCare',
      description: 'Notifications pour les alertes de zone',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // LIGNE CORRIGÉE ICI (ajout du <)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handler messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handler messages quand app ouverte
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM Foreground] Message recu: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handler quand utilisateur clique sur notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] App ouverte via notification');
    });
  }

  // Récupérer et sauvegarder le token FCM
  static Future<void> saveTokenForUser(String uid) async {
    try {
      String? token = await _messaging.getToken();

      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });

        print('[FCM] Token sauvegarde: $token');
      }

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('[FCM] Erreur sauvegarde token: $e');
    }
  }

  // Afficher notification locale
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'alzhecare_channel',
      'Alertes AlzheCare',
      channelDescription: 'Notifications pour les alertes de zone',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'AlzheCare',
      message.notification?.body ?? 'Nouvelle notification',
      details,
      payload: message.data.toString(),
    );
  }

  // Envoyer notification au suiveur
  static Future<void> sendNotificationToCaregiver({
    required String patientUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Récupérer l'UID du suiveur
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final caregiverUid = patientDoc.data()?['linkedCaregiver'] as String?;

      if (caregiverUid == null) {
        print('[FCM] Aucun suiveur lie');
        return;
      }

      // Récupérer le token FCM du suiveur
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      final fcmToken = caregiverDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        print('[FCM] Suiveur sans token FCM');
        return;
      }

      // Créer une notification dans Firestore
      // (Sera traitée par Cloud Functions ou service backend)
      // Créer une notification dans Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'caregiverUid': caregiverUid,  // AJOUTER pour le query
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('[FCM] Notification creee pour le suiveur');

    } catch (e) {
      print('[FCM] Erreur envoi notification: $e');
    }
  }
}