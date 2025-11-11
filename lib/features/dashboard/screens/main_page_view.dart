import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/dashboard/controllers/main_page_controller.dart';
import '/features/devices/models/device_model.dart';

/// The UI component for the main dashboard, displaying the list of devices.
class MainPageView extends StatelessWidget {
  const MainPageView({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the controller for state changes
    final controller = context.watch<MainPageController>();
    final devices = controller.devices;

    Widget bodyContent;

    if (controller.errorMessage != null) {
      bodyContent = Center(child: Text('Error: ${controller.errorMessage!}'));
    } else if (devices.isEmpty) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 60, color: Colors.black38),
              const SizedBox(height: 16),
              Text(
                'No devices added yet. Tap the "+" button to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    } else {
      // Display devices either in GridView or ListView
      bodyContent = controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Added loading state check
          : controller.isGrid
          ? GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // Adjusted aspect ratio to be slightly taller to fit all content
                childAspectRatio: 1.3,
              ),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return DeviceCard(device: devices[index]);
              },
            )
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                return DeviceListTile(
                  device: devices[index],
                ); // Use ListTile variant for List view
              },
            );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartEye Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => controller.logout(context),
          ),
          IconButton(
            icon: Icon(controller.isGrid ? Icons.list : Icons.grid_view),
            onPressed: controller.toggleView,
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add_device'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Reusable widget for displaying a single device in the list or grid (GRID view).
class DeviceCard extends StatelessWidget {
  final DeviceModel device;

  const DeviceCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/device_stream',
          arguments: device.id, // Pass the device ID for the stream page
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Reduced padding slightly
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.spaceAround, // Distribute space
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and Name
                  Flexible(
                    // Use Flexible to prevent name overflow
                    child: Text(
                      device.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16, // Slightly reduced font size
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Online Status
                  Icon(
                    device.isOnline
                        ? Icons.signal_cellular_alt
                        : Icons.signal_cellular_off,
                    color: device.isOnline
                        ? Colors.green[600]
                        : Colors.red[400],
                    size: 20, // Reduced icon size
                  ),
                ],
              ),
              // Use smaller vertical gaps
              const SizedBox(height: 4),

              // Display power status
              Text(
                'Power: ${device.isPoweredOn ? 'ON' : 'OFF'}',
                style: TextStyle(
                  fontSize: 13,
                  color: device.isPoweredOn ? Colors.green : Colors.red,
                ),
              ),
              // Display motion detection status
              Text(
                'Motion Detection: ${device.isMotionDetectionEnabled ? 'Enabled' : 'Disabled'}',
                style: TextStyle(
                  fontSize: 13,
                  color: device.isMotionDetectionEnabled
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 8),

              // Display ID
              Text(
                'ID: ${device.id}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable widget for displaying a single device in the list or grid (LIST view).
class DeviceListTile extends StatelessWidget {
  final DeviceModel device;

  const DeviceListTile({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[100],
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(
          context,
          '/device_stream',
          arguments: device.id,
        ),
        leading: Icon(
          device.isOnline ? Icons.videocam : Icons.videocam_off,
          color: device.isOnline ? Colors.green[600] : Colors.red[400],
        ),
        title: Text(
          device.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${device.id}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            Text(
              'Power: ${device.isPoweredOn ? 'ON' : 'OFF'}',
              style: TextStyle(
                fontSize: 12,
                color: device.isPoweredOn ? Colors.green : Colors.red,
              ),
            ),
            Text(
              'Motion: ${device.isMotionDetectionEnabled ? 'Enabled' : 'Disabled'}',
              style: TextStyle(
                fontSize: 12,
                color: device.isMotionDetectionEnabled
                    ? Colors.green
                    : Colors.red,
              ),
            ),
          ],
        ),
        trailing: Icon(
          device.isOnline
              ? Icons.signal_cellular_alt
              : Icons.signal_cellular_off,
          color: device.isOnline ? Colors.green[600] : Colors.red[400],
        ),
      ),
    );
  }
}
