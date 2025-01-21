const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// Scheduled function to send notifications
exports.sendFlightReminders = onSchedule('every 24 hours', async (event) => {
  const today = new Date();
  const threeDaysFromNow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 3);

  // Get flights that depart in the next 3 days
  const flightsSnapshot = await getFirestore()
    .collection('flights')
    .where('departure_time', '>=', today.toISOString())
    .where('departure_time', '<=', threeDaysFromNow.toISOString())
    .get();

  const notifications = [];

  flightsSnapshot.forEach((doc) => {
    const flightData = doc.data();
    const fcmToken = flightData.fcmToken; // Ensure you have saved the FCM token with the flight

    if (fcmToken) {
      const payload = {
        notification: {
          title: 'Flight Reminder',
          body: `Your flight from ${flightData.from} to ${flightData.to} departs in 3 days!`,
        },
        token: fcmToken,
      };
      notifications.push(getMessaging().send(payload));
    }
  });

  // If there are notifications to send, send them in parallel
  await Promise.all(notifications);
});