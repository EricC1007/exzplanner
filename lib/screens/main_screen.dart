  import 'package:exzplanner/screens/login_screen.dart';
  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'expense_dashboard.dart';
  import 'chart_screen.dart';
  import 'camera_screen.dart';
  import 'trip_screen.dart';
  import 'flight_screen.dart';
  import 'profile_screen.dart';

  class MainScreen extends StatefulWidget {
    static const routeName = '/main';

    const MainScreen({super.key});

    @override
    _MainScreenState createState() => _MainScreenState();
  }

  class _MainScreenState extends State<MainScreen> {
    int _currentIndex = 0;

    final List<Widget> _screens = [
      const ExpenseDashboard(),
      const ChartScreen(),
      const CameraScreen(),
      const TripScreen(),
      const FlightScreen(),
    ];

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ezxplanner'),
          automaticallyImplyLeading: false, // Disable the back button
          leading: IconButton(
            icon: const Icon(Icons.person), // Profile icon
            onPressed: () {
              // Navigate to the ProfileScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ),
        body: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasData) {
              // User is logged in
              return _screens[_currentIndex];
            }
            // User is not logged in, navigate to LoginScreen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                LoginScreen.routeName,
                (route) => false,
              );
            });
            return const Center(child: Text('Redirecting to login...'));
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Charts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Camera',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore),
              label: 'Trip',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flight_takeoff),
              label: 'Flight',
            ),
          ],
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black54,
        ),
      );
    }
  }