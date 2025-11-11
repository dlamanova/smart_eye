import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '/features/devices/controllers/device_stream_controller.dart';
import '/features/devices/models/device_model.dart';

/// The UI component for the live stream and device controls.
class DeviceStreamView extends StatelessWidget {
  const DeviceStreamView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceStreamController>();
    final DeviceModel? device = controller.device;

    // Hardcoded URL for demonstration, this should ideally come from the DeviceModel
    const streamUrl = 'http://172.105.86.156:8080/stream'; 

    Widget bodyContent;

    if (controller.errorMessage != null) {
      bodyContent = Center(
        child: Text(
          controller.errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    } else if (device == null) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else {
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Live Stream Display (Mjpeg) ---
            AspectRatio(
              aspectRatio: 16 / 9, // Standard video aspect ratio
              child: Container(
                color: Colors.black,
                child: Mjpeg(
                  stream: streamUrl,
                  isLive: true,
                  fit: BoxFit.contain, // Use contain to ensure full image is visible
                  error: (context, error, stack) => const Center(
                    child: Text(
                      'Stream Error: Could not connect.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Device Status and Controls ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Controls',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey[700]),
                    ),
                    const Divider(height: 20),
                    
                    // 1. Power State Toggle
                    _buildControlRow(
                      context,
                      title: 'Device Power',
                      subtitle: device.isPoweredOn ? 'Camera is recording and live.' : 'Camera is completely powered off.',
                      icon: Icons.power_settings_new,
                      value: device.isPoweredOn,
                      onChanged: controller.isToggling ? null : (_) => controller.togglePower(),
                      activeColor: Colors.green,
                    ),
                    const Divider(height: 10),

                    // 2. Motion Detection Toggle
                    _buildControlRow(
                      context,
                      title: 'Motion Detection',
                      subtitle: device.isMotionDetectionEnabled ? 'Active: Will send alerts on movement.' : 'Inactive: No motion alerts will be sent.',
                      icon: Icons.sensor_door,
                      value: device.isMotionDetectionEnabled,
                      onChanged: controller.isToggling ? null : (_) => controller.toggleMotionDetection(),
                      activeColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(device?.name ?? 'Live Stream'),
        backgroundColor: Colors.blueGrey,
      ),
      body: bodyContent,
    );
  }

  // Helper function to build a consistent control row
  Widget _buildControlRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color activeColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: value ? activeColor : Colors.grey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      ),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }
}