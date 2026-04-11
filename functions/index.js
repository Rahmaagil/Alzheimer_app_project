const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const fcmToken = notification.to;

    if (!fcmToken) {
      console.log('Pas de token FCM pour cette notification');
      return null;
    }

    const message = {
      token: fcmToken,
      notification: notification.notification || {
        title: notification.title || 'AlzheCare',
        body: notification.message || 'Nouvelle notification',
      },
      data: notification.data || {},
      android: {
        priority: notification.priority === 'high' ? 'high' : 'normal',
        notification: {
          channel_id: getChannelId(notification.type),
          priority: notification.priority === 'high' ? 'high' : 'normal',
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Notification envoyée avec succès:', response);

      await snap.ref.update({
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        fcmResponse: response,
      });

      return response;
    } catch (error) {
      console.log('Erreur envoi notification:', error);
      
      await snap.ref.update({
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return null;
    }
  });

function getChannelId(type) {
  switch (type) {
    case 'sos':
    case 'fall':
    case 'geofence':
      return 'alzhecare_alerts';
    case 'reminder':
    case 'medication':
      return 'alzhecare_reminders';
    case 'chat_message':
      return 'alzhecare_messages';
    default:
      return 'alzhecare_alerts';
  }
}