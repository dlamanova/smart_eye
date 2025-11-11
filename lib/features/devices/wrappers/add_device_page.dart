import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Updated to package imports
import '/features/devices/controllers/add_device_controller.dart';
import '../views/add_device_view.dart';
import '/services/firebase_service.dart';

/// The entry point for the Add Device feature.
/// This widget provides the AddDeviceController to the view tree
/// using ChangeNotifierProvider.
class AddDevicePage extends StatelessWidget {
  const AddDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    // We instantiate the service here (or get it from a MultiProvider)
    final firebaseService = FirebaseService();

    // We use ChangeNotifierProvider to manage the state/logic.
    return ChangeNotifierProvider(
      // Inject the FirebaseService into the controller
      create: (_) => AddDeviceController(firebaseService),
      // The child widget (the UI) now has access to the controller/logic.
      child: const AddDeviceView(),
    );
  }
}
