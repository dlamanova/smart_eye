import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Updated to package import
import '/features/devices/controllers/add_device_controller.dart'; 

/// This widget holds the design and structure (UI). 
/// It gets its data and calls logic methods from the AddDeviceController.
class AddDeviceView extends StatelessWidget {
  const AddDeviceView({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the controller to rebuild the UI when state changes
    final controller = context.watch<AddDeviceController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Device'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the Camera ID found on the Raspberry Pi (e.g., printed label or app setup screen).',
              style: TextStyle(fontSize: 16.0, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            
            // Camera Name Input
            TextField(
              controller: controller.cameraNameController,
              decoration: const InputDecoration(
                labelText: 'Camera Name',
                prefixIcon: Icon(Icons.videocam),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              enabled: !controller.isLoading,
            ),
            const SizedBox(height: 16),

            // Unique Camera ID Input
            TextField(
              controller: controller.cameraIdController,
              // Removed keyboardType: TextInputType.number as device IDs are often alphanumeric
              decoration: const InputDecoration(
                labelText: 'Unique Camera ID',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              ),
              enabled: !controller.isLoading,
            ),
            const SizedBox(height: 32),

            // Add Camera Button
            ElevatedButton(
              onPressed: controller.isLoading
                  ? null
                  : () => controller.addCamera(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: controller.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'Add Camera',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),

            // Error/Success Message Display
            if (controller.errorMessage != null)
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle( 
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}