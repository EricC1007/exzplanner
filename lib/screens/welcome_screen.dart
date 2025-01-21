import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart'; // Import your main screen
// Import the TripScreen
// Import the FlightScreen

class WelcomeScreen extends StatefulWidget {
  static const routeName = '/welcome';

  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // List of onboarding pages
  final List<Widget> _onboardingPages = [
    const OnboardingPage(
      icon: Icons.list,
      imagePaths: ['assets/expense1.png', 'assets/expense2.png'], // Two images
      title: 'Track Your Expenses',
      description:
          'Easily add and manage your daily expenses. Keep track of where your money goes and stay on top of your budget. With detailed categorization and real-time updates, you can monitor your spending habits and make smarter financial decisions.',
    ),
    const OnboardingPage(
      icon: Icons.bar_chart,
      imagePaths: ['assets/chart.png'], // Single image
      title: 'View Charts',
      description:
          'Analyze your spending with visual charts. Understand your spending patterns and make informed financial decisions. Our intuitive charts provide a clear overview of your expenses, helping you identify trends and areas where you can save money.',
    ),
    const OnboardingPage(
      icon: Icons.camera_alt,
      imagePaths: ['assets/camera.png'], 
      title: 'Scan Receipts',
      description:
          'Use your camera to scan receipts and automatically add expenses. Save time and keep your records organized. Our advanced OCR technology ensures accurate data entry, so you can focus on managing your finances without the hassle of manual input.',
    ),
    const OnboardingPage(
      icon: Icons.landscape,
      imagePaths: ['assets/trip.png','assets/trip2.png'], 
      title: 'Plan Your Trips',
      description:
          'Schedule and manage your trips with ease. Keep track of your travel plans and expenses all in one place. Whether you\'re planning a weekend getaway or a long vacation, our trip planner helps you stay organized and within budget.',
    ),
    const OnboardingPage(
      icon: Icons.airplanemode_active,
      imagePaths: ['assets/flight.png', 'assets/flight2.png'], // Two images
      title: 'Manage Flights',
      description:
          'Add and manage your flight details. Keep track of your flight schedules and expenses. Our flight management feature ensures you never miss a flight and helps you keep your travel budget under control.',
    ),
  ];

  // Navigate to the next page
  void _nextPage() {
    if (_currentPage < _onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
      });
    }
  }

  // Navigate to the previous page
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to ExzPlanner'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          // PageView for onboarding pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: _onboardingPages,
            ),
          ),
          // Bottom navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: const Text(
                      'Back',
                      style: TextStyle(fontSize: 16, color: Colors.teal),
                    ),
                  ),
                // Next or Get Started button
                if (_currentPage < _onboardingPages.length - 1)
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                if (_currentPage == _onboardingPages.length - 1)
                  ElevatedButton(
                    onPressed: () async {
                      // Set the isFirstLogin flag to false
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isFirstLogin', false);

                      // Navigate to the main screen
                      Navigator.of(context)
                          .pushReplacementNamed(MainScreen.routeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Onboarding page widget
class OnboardingPage extends StatelessWidget {
  final IconData icon;
  final List<String> imagePaths; // List of image paths
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.imagePaths, // List of image paths
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Display multiple images in a Row or Column
          if (imagePaths.length == 1)
            Image.asset(
              imagePaths[0],
              height: screenHeight * 0.4, // 40% of screen height
              width: screenWidth * 0.9, // 80% of screen width
            ),
          if (imagePaths.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: imagePaths
                  .map((path) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Image.asset(
                          path,
                          height: screenHeight * 0.5, // 30% of screen height
                          width: screenWidth * 0.4, // 35% of screen width
                        ),
                      ))
                  .toList(),
            ),
          const Spacer(), // Pushes content below to the bottom
          Icon(
            icon,
            size: 30, // Further reduced icon size
            color: Colors.teal,
          ),
          const SizedBox(height: 8), // Reduced space after icon
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8), // Reduced space after title
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(), // Pushes content above to the top
        ],
      ),
    );
  }
}