import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import Provider package

// Core imports
import '/core/firebase_options.dart';
import '/core/app_theme.dart';
import '/services/firebase_service.dart'; // Handles device state updates
import '/services/janus_service.dart'; // <<< NEW: Handles WebRTC signaling via WebSocket

// Feature screens (Routes)
import '/features/auth/screens/splash_screen.dart';
import '/features/auth/screens/login_page.dart';
import '/features/auth/screens/register_page.dart';
import 'features/dashboard/wrappers/main_page.dart';
import 'features/devices/wrappers/add_device_page.dart';
import 'features/devices/wrappers/device_stream_page.dart';
import 'features/devices/controllers/device_stream_controller.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase using the core options file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 1. Instantiate the single service instances
  final FirebaseService firebaseService = FirebaseService();
  final JanusService janusService = JanusService(); // Instantiate Janus Service
  await firebaseService.initNotifications();

  runApp(
    // 2. Provide both services globally using MultiProvider
    MultiProvider( // Changed from single Provider to MultiProvider
      providers: [
        // Firebase is provided for device state (power/motion)
        Provider<FirebaseService>.value(
          value: firebaseService,
        ),
        // Janus is provided for WebRTC signaling
        Provider<JanusService>.value( 
          value: janusService,
        ),
      ],
      child: const SmartEyeApp(),
    ),
  );
}

class SmartEyeApp extends StatelessWidget {
  const SmartEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartEye',
      // Use the external theme file
      theme: AppTheme.lightTheme,

      // The application starts at the SplashScreen
      initialRoute: '/',

      // Route definitions updated for WebRTC setup
      routes: {
        // Define the SplashScreen for the root route
        '/': (context) => const SplashScreen(),

        '/main': (context) => const MainPage(),
        '/add_device': (context) => const AddDevicePage(),

        // --- WEBRTC SETUP: Inject DeviceStreamController here ---
        '/device_stream': (context) {
          // 1. Retrieve the arguments (expected to be a device ID string)
          final String? deviceId =
              ModalRoute.of(context)?.settings.arguments as String?;

          if (deviceId == null) {
            // Handle error case: Device ID is required for streaming
            return const Scaffold(
              body: Center(
                child: Text('Error: Device ID not provided for stream.'),
              ),
            );
          }

          // 2. Get the globally provided services instances
          final firebaseService = Provider.of<FirebaseService>(
            context,
            listen: false,
          );
          final janusService = Provider.of<JanusService>(// Get Janus Service
            context,
            listen: false,
          );

          // 3. Wrap the destination page with the WebRTC Controller Provider
          // NOTE: The constructor expects (FirebaseService, JanusService, String deviceId)
          return ChangeNotifierProvider(
            // Create the DeviceStreamController, passing both services
            create: (_) => DeviceStreamController(
              firebaseService, 
              janusService, 
              deviceId!, // Assert non-null because we checked above
            ),
            // DeviceStreamPage will use the controller via Consumer or Provider.of
            child: const DeviceStreamPage(),
          );
        },

        // --- AUTH ROUTES ---
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}