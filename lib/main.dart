import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Core imports (Updated to package imports)
import '/core/firebase_options.dart';
import '/core/app_theme.dart';

// Feature screens (Routes - Updated to package imports)
import '/features/auth/screens/splash_screen.dart';
// New Auth Screens
import '/features/auth/screens/login_page.dart';
import '/features/auth/screens/register_page.dart';
// Main App Screens
import 'features/dashboard/wrappers/main_page.dart';
import 'features/devices/wrappers/add_device_page.dart';
import 'features/devices/wrappers/device_stream_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase using the core options file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartEyeApp());
}

class SmartEyeApp extends StatelessWidget {
  const SmartEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We will wrap the app in a MultiProvider later for controllers/services
    return MaterialApp(
      title: 'SmartEye',
      // Use the external theme file
      theme: AppTheme.lightTheme,

      // --- FIX: Use initialRoute instead of home to ensure the routes map is loaded ---
      // The application starts at the SplashScreen
      initialRoute: '/',

      // Route definitions updated to use the new file structure
      routes: {
        // Define the SplashScreen for the root route
        '/': (context) => const SplashScreen(),

        '/main': (context) => const MainPage(),
        '/add_device': (context) => const AddDevicePage(),
        '/device_stream': (context) => const DeviceStreamPage(),
        // --- AUTH ROUTES ---
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}
