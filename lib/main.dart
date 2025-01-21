import 'package:exzplanner/screens/admin_dashboard.dart';
import 'package:exzplanner/screens/expense_dashboard.dart';
import 'package:exzplanner/screens/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart'; // Import the welcome screen

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");

  if (message.notification != null) {
    print("Notification Title: ${message.notification!.title}");
    print("Notification Body: ${message.notification!.body}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions
  await requestNotificationPermissions();

  // Listen for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Got a message whilst in the foreground!");
    print("Message data: ${message.data}");

    if (message.notification != null) {
      print("Notification Title: ${message.notification!.title}");
      print("Notification Body: ${message.notification!.body}");
    }
  });

  // Check if the user is logged in
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final user = FirebaseAuth.instance.currentUser;

  // Determine the initial screen
  final initialRoute = (isLoggedIn && user != null) ? MainScreen.routeName : LoginScreen.routeName;

  runApp(ExpenseTrackerApp(initialRoute: initialRoute));
}

// Request notification permissions
Future<void> requestNotificationPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission (iOS only)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true, // Display alerts
    badge: true, // Update app badge
    sound: true, // Play sound
    provisional: false, // Provisional authorization (iOS 12+)
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  final String initialRoute;

  const ExpenseTrackerApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExzPlanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: initialRoute,
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        MainScreen.routeName: (context) => const MainScreen(),
        WelcomeScreen.routeName: (context) => const WelcomeScreen(),
        ExpenseDashboard.routeName: (context) => const ExpenseDashboard(),
        SignUpScreen.routeName: (context) => const SignUpScreen(),
        AdminDashboard.routeName: (context)=> const AdminDashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}