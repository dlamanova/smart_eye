import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/dashboard/controllers/main_page_controller.dart';
import '/features/dashboard/screens/main_page_view.dart';
import '/services/firebase_service.dart';

/// The entry point for the Main Dashboard feature.
/// This widget provides the MainPageController and the FirebaseService.
class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the FirebaseService as a dependency for the controller
    final firebaseService = FirebaseService(); 
    
    return ChangeNotifierProvider(
      // The controller takes the FirebaseService to perform data operations
      create: (_) => MainPageController(firebaseService),
      child: const MainPageView(),
    );
  }
}