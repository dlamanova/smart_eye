import 'package:flutter/material.dart';
import '../views/device_stream_view.dart';
// Note: Imports for controllers and services are no longer needed here
// because the controller is provided higher up in the widget tree (in main.dart).

/// The entry point for the Device Stream feature.
/// This widget acts as a simple wrapper, relying on the parent route (in main.dart)
/// to have provided the necessary DeviceStreamController via ChangeNotifierProvider.
class DeviceStreamPage extends StatelessWidget {
  const DeviceStreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We no longer manually retrieve deviceId or create the controller here.
    // The main.dart route handles the creation of:
    // ChangeNotifierProvider<DeviceStreamController>(
    //   create: (context) => DeviceStreamController(firebaseService, janusService, deviceId),
    //   child: const DeviceStreamPage(), // <--- We are here
    // )

    // Just return the view, which will consume the provided controller.
    return const DeviceStreamView();
  }
}
