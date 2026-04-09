import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tunis'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    await _requestPermissions();
    
    await _checkMissedReminders();
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> _checkMissedReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .where('done', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp?;
        final wasNotified = data['notifiedCaregiver'] as bool? ?? false;

        if (timestamp != null && !wasNotified) {
          final reminderTime = timestamp.toDate();
          final missedDuration = now.difference(reminderTime);
          
          if (missedDuration.inMinutes >= 30) {
            await _sendReminderMissedNotification(user.uid, data, doc.id);
          }
        }
      }
    } catch (e) {
      print("[Notification] Erreur vérification rappels manqués: $e");
    }
  }

  static Future<void> _sendReminderMissedNotification(String patientUid, Map<String, dynamic> reminderData, String reminderId) async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final patientName = patientDoc.data()?['name'] ?? 'Patient';
      final reminderTitle = reminderData['title'] as String? ?? 'Rappel';
      
      final linkedCaregivers = List<String>.from(
          patientDoc.data()?['linkedCaregivers'] ?? []
      );

      if (linkedCaregivers.isEmpty) return;

      final position = patientDoc.data()?['lastPosition'] as Map<String, dynamic>?;

      for (final caregiverId in linkedCaregivers) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'caregiverId': caregiverId,
          'patientId': patientUid,
          'patientName': patientName,
          'type': 'reminder_missed',
          'title': 'Rappel oublié',
          'message': '$patientName a oublié son rappel: "$reminderTitle"',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'reminderTitle': reminderTitle,
          'latitude': position?['latitude'],
          'longitude': position?['longitude'],
          'isRead': false,
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .collection('reminders')
          .doc(reminderId)
          .update({'notifiedCaregiver': true});

      print("[Notification] Notification rappel oublié envoyée à ${linkedCaregivers.length} caregiver(s)");
    } catch (e) {
      print("[Notification] Erreur envoi notification rappel oublié: $e");
    }
  }

  static Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        print("[Notification] Rappel passé, ignoré");
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Rappels',
        channelDescription: 'Notifications de rappels',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: 'notification_icon',
      );

      const details = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        reminderId.hashCode,
        'Rappel',
        title,
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      print("[Notification] Programmée: $title à $tzScheduledTime");
    } catch (e) {
      print("[Notification] Erreur: $e");
    }
  }

  static Future<void> cancelReminder(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
  }

  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  static Future<void> scheduleAllReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .where('done', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String?;
        final timestamp = data['date'] as Timestamp?;

        if (title != null && timestamp != null) {
          final dateTime = timestamp.toDate();

          if (dateTime.isAfter(DateTime.now())) {
            await scheduleReminder(
              reminderId: doc.id,
              title: title,
              scheduledTime: dateTime,
            );
          }
        }
      }
    } catch (e) {
      print("[Notification] Erreur: $e");
    }
  }
}