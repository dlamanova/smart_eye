import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// --- Core ---
import 'package:smart_eye/core/firebase_options.dart';
import 'package:smart_eye/core/theme_provider.dart';
import 'package:smart_eye/core/app_theme.dart';
import 'package:smart_eye/services/firebase_service.dart';
import 'package:smart_eye/services/janus_service.dart';
import 'package:smart_eye/services/fb_service.dart'; // Import FBService

// --- Screens (new design) ---
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/add_device_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/register_server_screen.dart';

// --- Controllers ---
import 'controllers/device_stream_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Firebase ---
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- Create services ---
  final firebaseService = FirebaseService();
  final janusService = JanusService();
  final fbService = FBService(); // Create FBService

  await firebaseService.initNotifications();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        Provider<JanusService>.value(value: janusService),
        Provider<FBService>.value(value: fbService), // Provide FBService
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const SmartEyeApp(),
    ),
  );
}

class SmartEyeApp extends StatelessWidget {
  const SmartEyeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SmartEye',
          debugShowCheckedModeBanner: false,
          
          // Use centralized theme definitions
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          initialRoute: '/',
          routes: {
            '/': (context) => const LoadingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => RegisterScreen(onRegister: () {}),
            '/devices': (context) => const DevicesScreen(),
            '/add-device': (context) => const AddDeviceScreen(),
            '/preferences': (context) => const PreferencesScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/register-server': (context) => const RegisterServerScreen(),
          },

          // --- Monitoring route with injected controllers ---
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/monitoring/') ?? false) {
              // Pattern: /monitoring/serverId/deviceId
              debugPrint('onGenerateRoute: Processing route: ${settings.name}');
              final segments = settings.name!.split('/');
              debugPrint('onGenerateRoute: Route segments: $segments');

              if (segments.length < 4) {
                debugPrint('onGenerateRoute: Invalid route - expected at least 4 segments, got ${segments.length}');
                return null;
              }

              final serverId = segments[segments.length - 2];
              final deviceId = segments.last;

              debugPrint('onGenerateRoute: Extracted serverId="$serverId", deviceId="$deviceId"');

              if (serverId.isEmpty) {
                debugPrint('onGenerateRoute: ERROR - serverId is EMPTY!');
              }
              if (deviceId.isEmpty) {
                debugPrint('onGenerateRoute: ERROR - deviceId is EMPTY!');
              }

              final firebaseService = Provider.of<FirebaseService>(
                context,
                listen: false,
              );
              final janusService = Provider.of<JanusService>(
                context,
                listen: false,
              );
              final fbService = Provider.of<FBService>(
                context,
                listen: false,
              );

              return MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider(
                  create: (_) => DeviceStreamController(
                    firebaseService,
                    fbService,
                    janusService,
                    deviceId,
                    serverId: serverId,
                  ),
                  child: MonitoringScreen(deviceId: deviceId),
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
