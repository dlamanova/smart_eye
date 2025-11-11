import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import StreamSubscription

/// The first screen displayed when the application starts.
/// It usually handles checking the user's authentication status
/// before navigating to Login or Dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // FIX 2C: Use a StreamSubscription to listen to auth state changes
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Start listening to auth changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      // Small delay ensures the SplashScreen UI is shown briefly
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        if (user != null) {
          // If logged in, go to the main dashboard
          // Use pushNamedAndRemoveUntil to clear the navigation stack
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        } else {
          // If not logged in, go to the login page
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    });
  }

  @override
  void dispose() {
    // Crucial: Cancel the subscription to prevent memory leaks
    _authSubscription.cancel();
    super.dispose();
  }

  // NOTE: We no longer need _checkAuthStatus() since we use the stream.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 20),
            Text(
              'SmartEye Security',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
