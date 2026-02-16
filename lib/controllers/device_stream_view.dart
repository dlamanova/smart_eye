import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Assuming these are your paths to the controller and model
import 'device_stream_controller.dart';
import '/models/device.dart';

/// The UI view for displaying the device stream and controls.
class DeviceStreamView extends StatelessWidget {
  const DeviceStreamView({super.key});

  @override
  Widget build(BuildContext context) {
    // We use a Consumer to listen to changes in the DeviceStreamController
    return Consumer<DeviceStreamController>(
      builder: (context, controller, child) {
        final device = controller.device;

        // --- Error/Loading State Handling ---
        if (controller.errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Device Error')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: ${controller.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (device == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Connecting...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // --- Main Content ---
        return Scaffold(
          appBar: AppBar(
            title: Text(device.name),
            backgroundColor: device.isPoweredOn
                ? Colors.blue.shade800
                : Colors.grey.shade600,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Video Stream Renderer
                _buildVideoStream(controller),
                const SizedBox(height: 24),

                // 2. Device Status
                _buildStatusCard(device),
                const SizedBox(height: 24),

                // 3. Control Buttons
                _buildControls(context, controller, device),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the WebRTC video rendering widget.
  Widget _buildVideoStream(DeviceStreamController controller) {
    // Check if the remote renderer has a source object (i.e., if the stream is connected)
    final isStreaming = controller.remoteRenderer.srcObject != null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade700, width: 2),
        ),
        child: isStreaming
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  controller.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Connecting to stream...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    Text(
                      'Waiting for SDP Answer and ICE Candidates',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Builds a card summarizing the device status.
  Widget _buildStatusCard(Device device) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const Divider(height: 20),
            _statusRow(
              'Power Status:',
              device.isPoweredOn ? 'ON' : 'OFF',
              device.isPoweredOn ? Colors.green : Colors.red,
              device.isPoweredOn ? Icons.power_settings_new : Icons.power_off,
            ),
            _statusRow(
              'Motion Detection:',
              device.isMotionDetectionEnabled ? 'ACTIVE' : 'INACTIVE',
              device.isMotionDetectionEnabled ? Colors.orange : Colors.grey,
              device.isMotionDetectionEnabled
                  ? Icons.motion_photos_on
                  : Icons.motion_photos_off,
            ),
          ],
        ),
      ),
    );
  }

  /// Helper for building individual status rows.
  Widget _statusRow(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Builds the control buttons section.
  Widget _buildControls(
    BuildContext context,
    DeviceStreamController controller,
    Device device,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Controls',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Power Toggle Button
            _controlButton(
              context: context,
              icon: device.isPoweredOn
                  ? Icons.power_settings_new
                  : Icons.power_off,
              label: device.isPoweredOn ? 'Turn OFF' : 'Turn ON',
              color: device.isPoweredOn
                  ? Colors.red.shade600
                  : Colors.green.shade600,
              onPressed: controller.isToggling ? null : controller.togglePower,
              isEnabled: device.isPoweredOn,
            ),

            // Motion Detection Toggle Button
            _controlButton(
              context: context,
              icon: device.isMotionDetectionEnabled
                  ? Icons.visibility_off
                  : Icons.visibility,
              label: device.isMotionDetectionEnabled
                  ? 'Disable Motion'
                  : 'Enable Motion',
              color: device.isMotionDetectionEnabled
                  ? Colors.orange.shade600
                  : Colors.blueGrey.shade600,
              onPressed: controller.isToggling
                  ? null
                  : controller.toggleMotionDetection,
              isEnabled: device.isMotionDetectionEnabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Connect / Disconnect Stream button (behaves like Back button disconnect/connect)
        Center(
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                await controller.toggleStreamConnection();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.remoteRenderer.srcObject != null
                          ? 'Connected to stream'
                          : 'Disconnected from stream',
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Stream toggle failed: $e')),
                );
              }
            },
            icon: Icon(
              controller.remoteRenderer.srcObject != null
                  ? Icons.link_off
                  : Icons.link,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 8.0,
              ),
              child: Text(
                controller.remoteRenderer.srcObject != null
                    ? 'Disconnect Stream'
                    : 'Connect Stream',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: controller.remoteRenderer.srcObject != null
                  ? Colors.red.shade600
                  : Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Helper for building interactive control buttons.
  Widget _controlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 5),
          Text(label),
        ],
      ),
    );
  }
}

// NOTE: For the app to run, you would typically use MultiProvider
// at the root of your application, wrapping the DeviceStreamView:
/*
void main() {
  // Ensure Firebase is initialized and dependencies are set up
  WidgetsFlutterBinding.ensureInitialized();

  // Example of how the view would be connected:
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => DeviceStreamController(
            FirebaseService(), // Replace with actual initialized service
            'your-device-id', // Replace with the actual device ID
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Stream App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DeviceStreamView(),
    );
  }
}
*/