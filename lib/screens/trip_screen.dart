import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../service/pexels_service.dart';
import 'trip_detail_screen.dart';

final userId = FirebaseAuth.instance.currentUser?.uid;

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  _TripScreenState createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PexelsService _pexelsService = PexelsService();
  bool _hasNewNotifications = false; // Track new notifications

  @override
  void initState() {
    super.initState();
    _checkForNewNotifications();
  }

  // Check for new notifications (announcements and recommendations)
  Future<void> _checkForNewNotifications() async {
    // Fetch all announcements
    final announcementsSnapshot =
        await _firestore.collection('announcements').get();

    // Fetch read announcements for the current user
    final readAnnouncementsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('read_announcements')
        .get();

    // Get IDs of read announcements
    final readAnnouncementIds =
        readAnnouncementsSnapshot.docs.map((doc) => doc.id).toList();

    // Check if there are any unread announcements
    setState(() {
      _hasNewNotifications = announcementsSnapshot.docs
          .any((doc) => !readAnnouncementIds.contains(doc.id));
    });
  }

  // Mark notifications as read
  Future<void> _markNotificationsAsRead() async {
    // Fetch all announcements
    final announcementsSnapshot =
        await _firestore.collection('announcements').get();

    // Mark each announcement as read for the current user
    for (var doc in announcementsSnapshot.docs) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('read_announcements')
          .doc(doc.id)
          .set({
        'readAt': DateTime.now(),
      });
    }

    setState(() {
      _hasNewNotifications = false;
    });
  }

  // Show notifications in a dialog with tabs
  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2, // Number of tabs
          child: AlertDialog(
            title: const Text('Notifications',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // Adjust height as needed
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Announcements'),
                      Tab(text: 'Recommendations'),
                    ],
                    labelStyle: TextStyle(
                        fontSize: 14), // Add this line to fix overflow
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Announcements Tab
                        SingleChildScrollView(
                          child: _buildAnnouncements(),
                        ),

                        // Recommendations Tab
                        SingleChildScrollView(
                          child: _buildRecommendations(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _markNotificationsAsRead(); // Mark notifications as read when the dialog is closed
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTrip() async {
    try {
      String countryName = _countryController.text.trim();
      String budgetString = _budgetController.text.trim();

      if (countryName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a country name.')));
        return;
      }

      double? budget = double.tryParse(budgetString);

      if (budget == null || budget <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid budget.')));
        return;
      }

      if (_fromDate == null ||
          _toDate == null ||
          _fromDate!.isAfter(_toDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select valid start and end dates.')),
        );
        return;
      }

      String? fromDateString = _fromDate?.toIso8601String();
      String? toDateString = _toDate?.toIso8601String();

      List<String> images = await _pexelsService.fetchImages(countryName);
      String? imageUrl = images.isNotEmpty ? images.first : null;

      // Save trip along with budget
      await _firestore.collection('trips').add({
        'country': countryName,
        'from_date': fromDateString,
        'to_date': toDateString,
        'user_id': userId ?? 'user_id_placeholder',
        'image_url': imageUrl,
        'budget': budget,
        'total_expenses': 0.0, // Initialize with 0
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Trip to $countryName scheduled with a budget of \$${budget.toStringAsFixed(2)}!'),
        ),
      );

      _countryController.clear();
      _fromDateController.clear();
      _toDateController.clear();
      _budgetController.clear();
      setState(() {
        _fromDate = null;
        _toDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error scheduling trip: $e')));
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return 'Unknown Date';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _fromDate) {
      setState(() {
        _fromDate = picked;
        _fromDateController.text = _formatDate(_fromDate)!;
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate ??
          (_fromDate?.add(const Duration(days: 1)) ?? DateTime.now()),
      firstDate: _fromDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _toDate) {
      setState(() {
        _toDate = picked;
        _toDateController.text = _formatDate(_toDate)!;
      });
    }
  }

  Widget _buildTripList(String title, Stream<QuerySnapshot> stream) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No trips found.'));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final tripData =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>?;

                if (tripData == null) {
                  return const ListTile(title: Text("Trip data not available"));
                }

                final String country = tripData['country'] ?? 'Unknown Country';
                final String fromDateString =
                    tripData['from_date'] ?? 'Unknown Start Date';
                final String toDateString =
                    tripData['to_date'] ?? 'Unknown End Date';
                final String? imageUrl = tripData['image_url'];
                final double budget = tripData['budget'] ?? 0.0;
                final double totalExpenses = tripData['total_expenses'] ?? 0.0;

                DateTime? fromDate;
                DateTime? toDate;
                try {
                  fromDate = DateTime.parse(fromDateString);
                  toDate = DateTime.parse(toDateString);
                } catch (e) {
                  print('Error parsing date: $e');
                }

                final String formattedFromDate = fromDate != null
                    ? DateFormat('dd/MM/yyyy').format(fromDate)
                    : 'Unknown Start Date';
                final String formattedToDate = toDate != null
                    ? DateFormat('dd/MM/yyyy').format(toDate)
                    : 'Unknown End Date';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripDetailScreen(
                              tripId: snapshot.data!.docs[index].id),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error);
                                },
                              ),
                            )
                          : const Icon(Icons.place, size: 50),
                      title: Text(country,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'From: $formattedFromDate\nTo: $formattedToDate\nBudget: RM${budget.toStringAsFixed(2)}\nTotal Expense for Places/Sightseeing: RM${totalExpenses.toStringAsFixed(2)}'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnnouncements() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('announcements').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No announcements found.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final announcementData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final String message = announcementData['message'] ?? 'No message';
            final Timestamp timestamp =
                announcementData['timestamp'] ?? Timestamp.now();
            final String formattedDate =
                DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                title: const Text('Announcement',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text('$message\n$formattedDate'),
                onTap: () {
                  _showAnnouncementDetail(
                      message, formattedDate); // Add this line
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showAnnouncementDetail(String message, String date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Announcement Detail',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: $date',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecommendations() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('recommendations')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No recommendations found.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final recommendationData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final String message =
                recommendationData['message'] ?? 'No message';
            final String tripId =
                recommendationData['tripId'] ?? 'Unknown Trip';
            final Timestamp timestamp =
                recommendationData['timestamp'] ?? Timestamp.now();
            final String formattedDate =
                DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());

            // Fetch trip details to get the country name
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('trips').doc(tripId).get(),
              builder: (context, tripSnapshot) {
                if (tripSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Loading...'),
                  );
                }

                if (tripSnapshot.hasError) {
                  return ListTile(
                    title: Text('Error: ${tripSnapshot.error}'),
                  );
                }

                if (!tripSnapshot.hasData || !tripSnapshot.data!.exists) {
                  return const ListTile(
                    title: Text('Trip not found'),
                  );
                }

                final tripData =
                    tripSnapshot.data!.data() as Map<String, dynamic>?;
                final String country =
                    tripData?['country'] ?? 'Unknown Country';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    title: Text('Recommendation for Trip to $country'),
                    subtitle: Text('$message\n$formattedDate'),
                    onTap: () {
                      _showRecommendationDetail(
                          message, formattedDate, country); // Add this line
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRecommendationDetail(String message, String date, String country) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Recommendation Detail',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: $date',
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 16),
                Text('Trip to: $country',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
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
        title: const Text('Trip Planner',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _showNotifications,
              ),
              if (_hasNewNotifications)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Flight Input Section
              Card(
                elevation: 5,
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _fromDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          hintText: 'Select a start date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _selectFromDate(context),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _toDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          hintText: 'Select an end date',
                          border: OutlineInputBorder(),
                        ),
                        onTap: () => _selectToDate(context),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Budget',
                          hintText: 'Enter your budget for the trip',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                        ),
                        child: const Text(
                          'Schedule Trip',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Trip List Section
              _buildTripList(
                'Upcoming Trips',
                _firestore
                    .collection('trips')
                    .where('user_id', isEqualTo: userId)
                    .where('from_date',
                        isGreaterThan: DateTime.now().toIso8601String())
                    .snapshots(),
              ),
              _buildTripList(
                'Ongoing Trips',
                _firestore
                    .collection('trips')
                    .where('user_id', isEqualTo: userId)
                    .where('from_date',
                        isLessThanOrEqualTo: DateTime.now().toIso8601String())
                    .where('to_date',
                        isGreaterThanOrEqualTo:
                            DateTime.now().toIso8601String())
                    .snapshots(),
              ),
              _buildTripList(
                'Past Trips',
                _firestore
                    .collection('trips')
                    .where('user_id', isEqualTo: userId)
                    .where('to_date',
                        isLessThan: DateTime.now().toIso8601String())
                    .snapshots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}