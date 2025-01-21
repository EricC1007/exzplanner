import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'flight_detail_screen.dart'; // Import the new FlightDetailScreen

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  _FlightScreenState createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _flightFromController = TextEditingController();
  final TextEditingController _flightToController = TextEditingController();
  final TextEditingController _flightCategoryController = TextEditingController();

  DateTime? _departureDateTime;

  // List of suggested cities
  final List<String> _suggestedCities = [
    'Kuala Lumpur',
    'Singapore',
    'Bangkok',
    'Tokyo',
    'New York',
    'London',
    'Sydney',
    'Paris',
    'Dubai',
    'Hong Kong',
  ];

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.requestPermission();
    _saveFCMToken();
  }

  Future<void> _saveFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (token != null && userId != null) {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addFlight() async {
    String flightFrom = _flightFromController.text;
    String flightTo = _flightToController.text;
    String flightCategory = _flightCategoryController.text;
    double flightCost = 0.0;

    final String? costInput = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController costController = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Flight Cost'),
          content: TextField(
            controller: costController,
            decoration: const InputDecoration(labelText: 'Cost in RM'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(costController.text),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (costInput != null && costInput.isNotEmpty) {
      try {
        flightCost = double.parse(costInput);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid cost entered.')),
        );
        return;
      }
    }

    if (flightFrom.isEmpty || flightTo.isEmpty || flightCategory.isEmpty || _departureDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    String? token = await FirebaseMessaging.instance.getToken();

    await _firestore.collection('flights').add({
      'from': flightFrom,
      'to': flightTo,
      'departure_time': _departureDateTime!.toIso8601String(),
      'userId': userId,
      'fcmToken': token,
      'cost': flightCost,
      'category': flightCategory,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Flight from $flightFrom scheduled, cost RM $flightCost in category $flightCategory')),
    );

    setState(() {
      _flightFromController.clear();
      _flightToController.clear();
      _flightCategoryController.clear();
      _departureDateTime = null;
    });
  }

  Future<void> _deleteFlight(String flightId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flight'),
        content: const Text('Are you sure you want to delete this flight and its associated expenses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      // Delete all expenses associated with the flight
      final expensesSnapshot = await _firestore
          .collection('flights')
          .doc(flightId)
          .collection('expenses')
          .get();

      for (var doc in expensesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the flight
      await _firestore.collection('flights').doc(flightId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flight and associated expenses deleted successfully.')),
      );
    }
  }

  Future<void> _selectDepartureTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _departureDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_departureDateTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _departureDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Widget _buildFlightList(String title, Stream<QuerySnapshot> stream) {
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
              return const Center(child: Text('No flights found.'));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final flightData = snapshot.data!.docs[index].data() as Map<String, dynamic>?;

                if (flightData == null) {
                  return const ListTile(title: Text("Flight data not available"));
                }

                final String from = flightData['from'] ?? 'Unknown Origin';
                final String to = flightData['to'] ?? 'Unknown Destination';
                final String departureTime = flightData['departure_time'] ?? 'Unknown Departure Time';
                final double cost = flightData['cost'] ?? 0.0;
                final String category = flightData['category'] ?? 'N/A';

                DateTime? departureDateTime;
                try {
                  departureDateTime = DateTime.parse(departureTime);
                } catch (e) {
                  print('Error parsing date: $e');
                }

                final String formattedDepartureTime = departureDateTime != null
                    ? _formatDateTime(departureDateTime)
                    : 'Unknown Departure Time';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    title: Text(
                      '$from to $to',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Departure: $formattedDepartureTime',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Cost: RM ${cost.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Category: $category',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFlight(snapshot.data!.docs[index].id),
                      tooltip: 'Delete flight',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlightDetailScreen(
                            flightId: snapshot.data!.docs[index].id,
                            flightCost: cost,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flight Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
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
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _suggestedCities.where((city) => city.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          _flightFromController.text = selection;
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Flight From',
                              hintText: 'Enter departure city',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _suggestedCities.where((city) => city.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          _flightToController.text = selection;
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Flight To',
                              hintText: 'Enter destination city',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _flightCategoryController,
                        decoration: const InputDecoration(
                          labelText: 'Expense Category',
                          hintText: 'Enter category (e.g. Business, Personal)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _selectDepartureTime,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: Text(
                          _departureDateTime != null
                              ? 'Departure Time: ${_formatDateTime(_departureDateTime!)}'
                              : 'Select Departure Time',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addFlight,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text(
                          'Schedule Flight',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Upcoming Flights Section
              _buildFlightList(
                'Upcoming Flights',
                _firestore
                    .collection('flights')
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .where('departure_time', isGreaterThan: DateTime.now().toIso8601String())
                    .snapshots(),
              ),
              // Past Flights Section
              _buildFlightList(
                'Past Flights',
                _firestore
                    .collection('flights')
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .where('departure_time', isLessThan: DateTime.now().toIso8601String())
                    .snapshots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}