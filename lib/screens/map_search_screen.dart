import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';

class MapSearchScreen extends StatefulWidget {
  final String tripId;

  const MapSearchScreen({required this.tripId, super.key});

  @override
  _MapSearchScreenState createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends State<MapSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final Set<Marker> _markers = {};
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  String? _selectedPlaceName;

  bool _budgetChecked = false;
  double _remainingBudget = 0.0; // to store remaining budget

  // Helper function to check if a string is a number
  bool isNumber(String s) {
    return double.tryParse(s) != null;
  }

  @override
  void initState() {
    super.initState();
    _getBudget();
  }

  Future<void> _getBudget() async {
    DocumentSnapshot tripDoc = await _firestore.collection('trips').doc(widget.tripId).get();
    double budget = tripDoc['budget'] ?? 0.0;
    double totalExpenses = tripDoc['total_expenses'] ?? 0.0;
    setState(() {
      _remainingBudget = budget - totalExpenses; // calculate remaining budget
      _budgetChecked = true;
    });
  }

  void _addSchedule(LatLng latLng, String placeName, double cost) async {
    print('Adding place: $placeName'); // Debugging
    try {
      await _firestore.collection('trips').doc(widget.tripId).collection('schedule').add({
        'place': placeName,
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
        'cost': cost, // Add this cost field
      });

      // Update the total expenses for the trip
      DocumentReference tripRef = FirebaseFirestore.instance.collection('trips').doc(widget.tripId);
      await tripRef.update({
        'total_expenses': FieldValue.increment(cost), // Increment the existing total expenses
      });
      
      // Update the remainingBudget after adding cost
      setState(() {
        _remainingBudget -= cost;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $placeName to the schedule')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding place: $e')),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        LatLng latLng = LatLng(locations[0].latitude, locations[0].longitude);
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

        // Improved place name retrieval logic
        String placeName = query; // Default to the search query
        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks[0];
          // Use placemark.name if it's not a number, otherwise use the search query
          placeName = placemark.name != null && !isNumber(placemark.name!) ? placemark.name! : query;
        }

        print('Place Name from Placemark: $placeName'); // Debugging

        setState(() {
          _selectedLocation = latLng;
          _selectedPlaceName = placeName;
          _markers.clear();
          String markerId = const Uuid().v4();
          _markers.add(
            Marker(
              markerId: MarkerId(markerId),
              position: latLng,
              infoWindow: InfoWindow(title: placeName),
            ),
          );
        });
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null || _selectedPlaceName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }

    double? cost = double.tryParse(_costController.text.trim());
    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cost')),
      );
      return;
    }

    // Add the place directly without asking for time
    _addSchedule(_selectedLocation!, _selectedPlaceName!, cost);
  }

  // Capitalize the first character of the search query
  String _capitalizeFirstLetter(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Places'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search for a place...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // Capitalize the first character of the input
                      if (value.isNotEmpty) {
                        _searchController.value = TextEditingValue(
                          text: _capitalizeFirstLetter(value),
                          selection: _searchController.selection,
                        );
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      print('Search Query: ${_searchController.text}'); // Debugging
                      _searchLocation(_searchController.text);
                    }
                  },
                ),
              ],
            ),
          ),
          // TextField for entering cost
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter cost in RM...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              onTap: (LatLng latLng) async {
                List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

                // Improved place name retrieval logic
                String placeName = 'Selected Location'; // Default value
                if (placemarks.isNotEmpty) {
                  Placemark placemark = placemarks[0];
                  placeName = placemark.name != null && !isNumber(placemark.name!) ? placemark.name! : 'Selected Location';
                }

                print('Place Name from Placemark on Map Tap: $placeName'); // Debugging

                setState(() {
                  _selectedLocation = latLng;
                  _selectedPlaceName = placeName;
                  _markers.clear();
                  String markerId = const Uuid().v4();
                  _markers.add(
                    Marker(
                      markerId: MarkerId(markerId),
                      position: latLng,
                      infoWindow: InfoWindow(title: placeName),
                    ),
                  );
                });
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194), // Default location (San Francisco)
                zoom: 10,
              ),
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _confirmLocation,
              child: const Text('Confirm Location'),
            ),
          ),
          // Display remaining budget
          if (_budgetChecked) 
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _remainingBudget >= 0
                    ? 'Remaining Budget: RM ${_remainingBudget.toStringAsFixed(2)}'
                    : 'Exceeded Budget by RM ${(-_remainingBudget).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _remainingBudget >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}