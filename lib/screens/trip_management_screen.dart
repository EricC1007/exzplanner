import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TripManagementScreen extends StatefulWidget {
  const TripManagementScreen({super.key});

  @override
  _TripManagementScreenState createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> trips = [];
  List<Map<String, dynamic>> announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchTrips();
    _fetchAnnouncements();
  }

  // Fetch trips from Firestore
  Future<void> _fetchTrips() async {
    QuerySnapshot snapshot = await _firestore.collection('trips').get();
    List<Map<String, dynamic>> tripList = [];

    for (var tripDoc in snapshot.docs) {
      var tripData = tripDoc.data() as Map<String, dynamic>;

      tripList.add({
        'tripId': tripDoc.id,
        'country': tripData['country'],
        'fromDate': tripData['from_date'],
        'toDate': tripData['to_date'],
      });
    }

    setState(() {
      trips = tripList;
    });
  }

  // Fetch announcements from Firestore
  Future<void> _fetchAnnouncements() async {
    QuerySnapshot snapshot = await _firestore.collection('announcements').get();
    List<Map<String, dynamic>> announcementList = [];

    for (var announcementDoc in snapshot.docs) {
      var announcementData = announcementDoc.data() as Map<String, dynamic>;

      announcementList.add({
        'announcementId': announcementDoc.id,
        'message': announcementData['message'],
        'timestamp': announcementData['timestamp'],
      });
    }

    setState(() {
      announcements = announcementList;
    });
  }

  // Delete a trip
  void _deleteTrip(String tripId) async {
    await _firestore.collection('trips').doc(tripId).delete();
    _fetchTrips(); // Refresh the trips list
  }

  // Delete an announcement
  void _deleteAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).delete();
    _fetchAnnouncements(); // Refresh the announcements list
  }

  // Send a recommendation to a user
  void _sendRecommendation(String tripId) async {
    TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Recommendation'),
          content: TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Enter your recommendation',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.isNotEmpty) {
                  // Fetch the trip to get the userId
                  final tripSnapshot =
                      await _firestore.collection('trips').doc(tripId).get();
                  final tripData = tripSnapshot.data();

                  if (tripData != null) {
                    final String userId = tripData['user_id'];

                    // Save recommendation to Firestore with userId
                    await _firestore.collection('recommendations').add({
                      'tripId': tripId,
                      'message': messageController.text,
                      'timestamp': DateTime.now(),
                      'userId': userId, // Add userId to the recommendation
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Recommendation sent successfully!')),
                    );

                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Trip not found.')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a recommendation.')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  // Send an announcement to all users
  void _sendAnnouncement() async {
    TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Announcement'),
          content: TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Enter your announcement',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (messageController.text.isNotEmpty) {
                  // Save announcement to Firestore
                  await _firestore.collection('announcements').add({
                    'message': messageController.text,
                    'timestamp': DateTime.now(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Announcement sent successfully!')),
                  );

                  Navigator.pop(context);
                  _fetchAnnouncements(); // Refresh the announcements list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter an announcement.')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.announcement),
            onPressed: _sendAnnouncement,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Trips Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Trips',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                var trip = trips[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(trip['country']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From: ${trip['fromDate']}'),
                        Text('To: ${trip['toDate']}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.message),
                      onPressed: () => _sendRecommendation(trip['tripId']),
                    ),
                  ),
                );
              },
            ),

            // Announcements Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Announcements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                var announcement = announcements[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(announcement['message']),
                    subtitle: Text(
                        'Sent on: ${DateFormat('dd/MM/yyyy HH:mm').format((announcement['timestamp'] as Timestamp).toDate())}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _deleteAnnouncement(announcement['announcementId']),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}