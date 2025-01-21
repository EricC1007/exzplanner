import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'user_management_screen.dart'; // Keep user management
import 'trip_management_screen.dart'; // Keep trip management
import 'login_screen.dart'; // Import the LoginScreen

class AdminDashboard extends StatelessWidget {
  static const routeName = '/admin';

  const AdminDashboard({super.key});

  // Function to handle logout
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut(); // Sign out the user
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName); // Navigate to LoginScreen
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log out. Please try again.')),
      );
    }
  }

  // User Statistics
  Future<int> _getTotalUsers() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    return usersSnapshot.docs.length;
  }

  Future<int> _getActiveUsers() async {
    final activeUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('last_active', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
        .get();
    return activeUsersSnapshot.docs.length;
  }

  Future<int> _getNewUsers(String period) async {
    DateTime startDate;
    switch (period) {
      case 'daily':
        startDate = DateTime.now().subtract(const Duration(days: 1));
        break;
      case 'weekly':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case 'monthly':
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime.now();
    }
    final newUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('created_at', isGreaterThan: startDate.toIso8601String())
        .get();
    return newUsersSnapshot.docs.length;
  }

  // Trip Statistics
  Future<int> _getTotalTrips() async {
    final tripsSnapshot = await FirebaseFirestore.instance.collection('trips').get();
    return tripsSnapshot.docs.length;
  }

  Future<int> _getUpcomingTrips() async {
    final upcomingTripsSnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('from_date', isGreaterThan: DateTime.now().toIso8601String())
        .get();
    return upcomingTripsSnapshot.docs.length;
  }

  Future<int> _getOngoingTrips() async {
    final ongoingTripsSnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('from_date', isLessThanOrEqualTo: DateTime.now().toIso8601String())
        .where('to_date', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
        .get();
    return ongoingTripsSnapshot.docs.length;
  }

  Future<int> _getPastTrips() async {
    final pastTripsSnapshot = await FirebaseFirestore.instance
        .collection('trips')
        .where('to_date', isLessThan: DateTime.now().toIso8601String())
        .get();
    return pastTripsSnapshot.docs.length;
  }

  Future<List<ChartData>> _getPopularDestinations() async {
    final tripsSnapshot = await FirebaseFirestore.instance.collection('trips').get();
    final destinationCounts = <String, int>{};
    for (var trip in tripsSnapshot.docs) {
      final country = trip['country'] ?? 'Unknown';
      destinationCounts[country] = (destinationCounts[country] ?? 0) + 1;
    }
    final sortedDestinations = destinationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedDestinations.take(5).map((e) => ChartData(e.key, e.value)).toList();
  }

  // Flight Statistics
  Future<int> _getTotalFlights() async {
    final flightsSnapshot = await FirebaseFirestore.instance.collection('flights').get();
    return flightsSnapshot.docs.length;
  }

  Future<int> _getUpcomingFlights() async {
    final upcomingFlightsSnapshot = await FirebaseFirestore.instance
        .collection('flights')
        .where('departure_time', isGreaterThan: DateTime.now().toIso8601String())
        .get();
    return upcomingFlightsSnapshot.docs.length;
  }

  Future<int> _getPastFlights() async {
    final pastFlightsSnapshot = await FirebaseFirestore.instance
        .collection('flights')
        .where('departure_time', isLessThan: DateTime.now().toIso8601String())
        .get();
    return pastFlightsSnapshot.docs.length;
  }

  Future<List<ChartData>> _getPopularFlightRoutes() async {
    final flightsSnapshot = await FirebaseFirestore.instance.collection('flights').get();
    final routeCounts = <String, int>{};
    for (var flight in flightsSnapshot.docs) {
      final from = flight['from'] ?? 'Unknown';
      final to = flight['to'] ?? 'Unknown';
      final route = '$from to $to';
      routeCounts[route] = (routeCounts[route] ?? 0) + 1;
    }
    final sortedRoutes = routeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedRoutes.take(5).map((e) => ChartData(e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 10,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade100, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Application Icon (Rectangular Image)
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: const DecorationImage(
                    image: AssetImage('assets/exzplanner1.png'),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Welcome Text
              const Text(
                'Welcome, Admin!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 20),

              // Manage Users Card
              _buildManagementCard(
                context,
                icon: Icons.people,
                title: 'Manage Users',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
                },
              ),
              const SizedBox(height: 16),

              // Manage Trips Card
              _buildManagementCard(
                context,
                icon: Icons.flight,
                title: 'Manage Trips',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TripManagementScreen()));
                },
              ),
              const SizedBox(height: 16),

              // User Statistics
              const Text(
                'User Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                children: [
                  FutureBuilder<int>(
                    future: _getTotalUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Total Users', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getActiveUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Active Users (Last 30 Days)', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getNewUsers('monthly'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('New Users (Last 30 Days)', snapshot.data.toString());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trip Statistics
              const Text(
                'Trip Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                children: [
                  FutureBuilder<int>(
                    future: _getTotalTrips(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Total Trips', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getUpcomingTrips(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Upcoming Trips', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getOngoingTrips(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Ongoing Trips', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getPastTrips(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Past Trips', snapshot.data.toString());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Popular Destinations Chart
              FutureBuilder<List<ChartData>>(
                future: _getPopularDestinations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildChart('Popular Destinations', snapshot.data!);
                },
              ),
              const SizedBox(height: 16),

              // Flight Statistics
              const Text(
                'Flight Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                children: [
                  FutureBuilder<int>(
                    future: _getTotalFlights(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Total Flights', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getUpcomingFlights(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Upcoming Flights', snapshot.data.toString());
                    },
                  ),
                  FutureBuilder<int>(
                    future: _getPastFlights(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildStatCard('Past Flights', snapshot.data.toString());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Popular Flight Routes Chart
              FutureBuilder<List<ChartData>>(
                future: _getPopularFlightRoutes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildChart('Popular Flight Routes', snapshot.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.deepPurple),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.deepPurple),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(String title, List<ChartData> data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  enableAxisAnimation: true,
                  primaryXAxis: const CategoryAxis(
                    title: AxisTitle(text: 'Category'),
                    labelRotation: -45,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  primaryYAxis: const NumericAxis(
                    title: AxisTitle(text: 'Count'),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    majorGridLines: MajorGridLines(width: 1, color: Colors.grey),
                    minorGridLines: MinorGridLines(width: 0.5, color: Colors.grey),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                      return Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '${data.label}: ${data.value}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          maxLines: 2, // Allow text to wrap
                          overflow: TextOverflow.ellipsis, // Handle overflow
                        ),
                      );
                    },
                  ),
                  series: <CartesianSeries<ChartData, String>>[
                    BarSeries<ChartData, String>(
                      dataSource: data,
                      xValueMapper: (ChartData data, _) => data.label,
                      yValueMapper: (ChartData data, _) => data.value,
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade300,
                          Colors.blue.shade300,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        overflowMode: OverflowMode.hide, 
                      ),
                      animationDuration: 1000,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChartData {
  final String label;
  final int value;

  ChartData(this.label, this.value);
}