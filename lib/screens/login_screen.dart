import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart'; // Import your main screen
import 'sign_up_screen.dart'; // Import your sign-up screen
import 'admin_dashboard.dart'; // Import the admin dashboard
import 'welcome_screen.dart'; // Import the welcome screen

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Google Sign-In
  Future<UserCredential?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print(e);
      return null;
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveFCMToken(String userId) async {
    try {
      String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': fcmToken,
        }, SetOptions(merge: true));
        print('FCM Token saved to Firestore for user: $userId');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Save login state to shared_preferences
  Future<void> _saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  // Check if user is admin
  bool _isAdmin(String email) {
    return email == 'admin@gmail.com'; // Directly check if the email is admin@gmail.com
  }

  // Email and Password Login
  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both email and password')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Check if the user is admin
      bool adminStatus = _isAdmin(userCredential.user!.email!);

      // Save FCM token to Firestore only if the user is not an admin
      if (userCredential.user != null && !adminStatus) {
        await _saveFCMToken(userCredential.user!.uid);
      }

      // Save login state
      await _saveLoginState();

      // Redirect based on admin status
      if (adminStatus) {
        // Navigate to the admin dashboard
        Navigator.of(context).pushReplacementNamed(AdminDashboard.routeName);
      } else {
        // Check if it's the user's first login
        final prefs = await SharedPreferences.getInstance();
        bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

        if (isFirstLogin) {
          // Navigate to the welcome screen
          Navigator.of(context).pushReplacementNamed(WelcomeScreen.routeName);
        } else {
          // Navigate to the main screen
          Navigator.of(context).pushReplacementNamed(MainScreen.routeName);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome back!')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Authentication failed')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Reset loading state
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/exzplanner.png',
                    height: 250,
                    width: 200,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Easy And Pizzy ExzPlanner',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      // Navigate to the SignUpScreen
                      Navigator.of(context).pushNamed(SignUpScreen.routeName);
                    },
                    child: const Text(
                      'Don\'t have an account? Sign Up',
                      style: TextStyle(
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2.0,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                UserCredential? userCredential = await _signInWithGoogle();
                                if (userCredential != null) {
                                  // Check if the user is admin
                                  bool adminStatus = _isAdmin(userCredential.user!.email!);

                                  // Save FCM token to Firestore only if the user is not an admin
                                  if (!adminStatus) {
                                    await _saveFCMToken(userCredential.user!.uid);
                                  }

                                  // Save login state
                                  await _saveLoginState();

                                  // Redirect based on admin status
                                  if (adminStatus) {
                                    // Navigate to the admin dashboard
                                    Navigator.of(context).pushReplacementNamed(AdminDashboard.routeName);
                                  } else {
                                    // Check if it's the user's first login
                                    final prefs = await SharedPreferences.getInstance();
                                    bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

                                    if (isFirstLogin) {
                                      // Navigate to the welcome screen
                                      Navigator.of(context).pushReplacementNamed(WelcomeScreen.routeName);
                                    } else {
                                      // Navigate to the main screen
                                      Navigator.of(context).pushReplacementNamed(MainScreen.routeName);
                                    }
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Welcome back!')),
                                  );
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}