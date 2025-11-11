import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/devices/controllers/device_stream_controller.dart';
import '../views/device_stream_view.dart';
import '/services/firebase_service.dart';

/// The entry point for the Device Stream feature.
/// This widget retrieves the deviceId passed via arguments and provides
/// the DeviceStreamController to the view tree.
class DeviceStreamPage extends StatelessWidget {
  const DeviceStreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Retrieve the device ID passed from the dashboard
    final deviceId = ModalRoute.of(context)?.settings.arguments as String?;

    if (deviceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text(
            'Error: Device ID not provided.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // 2. Instantiate the service and controller
    final firebaseService = FirebaseService();

    return ChangeNotifierProvider(
      // The controller takes the FirebaseService and the deviceId
      create: (_) => DeviceStreamController(firebaseService, deviceId),
      child: const DeviceStreamView(),
    );
  }
}
