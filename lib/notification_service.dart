import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidInit);

    await _notifications.initialize(settings);
  }

  static Future<void> showGeofenceAlert({
    required int distance,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'geofence_channel',
      'Alerte de sécurité',
      channelDescription: 'Notifications de sortie de zone',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details =
    NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,
      "Alerte de sécurité",
      "Le patient est sorti de la zone sécurisée ($distance m)",
      details,
    );
  }
}