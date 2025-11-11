import 'dart:async';
import 'package:flutter/material.dart';
import '/features/devices/models/device_model.dart';
import '/services/firebase_service.dart';

/// Manages the state and logic for the main dashboard page.
class MainPageController extends ChangeNotifier {
  // --- Dependency Injection: Service must be passed in ---
  final FirebaseService _firebaseService;

  // State for streaming devices and view control
  List<DeviceModel> _devices = [];
  StreamSubscription? _deviceSubscription;
  bool _isLoading = true;
  bool _isGrid = true;
  String? _errorMessage; // NEW: Field to hold error messages

  List<DeviceModel> get devices => _devices;
  bool get isLoading => _isLoading;
  bool get isGrid => _isGrid;
  String? get errorMessage => _errorMessage; // NEW: Getter for error messages

  // 2. Accept the service via the constructor. This fixes the "Too many positional arguments" error.
  MainPageController(this._firebaseService) {
    _initDeviceStream();
  }

  /// Toggles between grid and list view for devices.
  void toggleView() {
    _isGrid = !_isGrid;
    notifyListeners();
  }

  /// Initializes the stream listener for user's devices.
  void _initDeviceStream() {
    _deviceSubscription?.cancel();

    _deviceSubscription = _firebaseService.streamUserDevices().listen(
      (deviceList) {
        _devices = deviceList;
        _isLoading = false;
        _errorMessage = null; // Clear error on successful data load
        notifyListeners();
      },
      onError: (error) {
        // CAPTURE ERROR: Store the error message
        debugPrint('Error listening to devices: $error');
        _errorMessage = 'Failed to load devices: ${error.toString()}';
        _isLoading = false;
        notifyListeners();
      },
      onDone: () {
        debugPrint('Device stream completed.');
      },
    );
  }

  /// Handles the user logout process.
  Future<void> logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firebaseService.signOut();

        _deviceSubscription?.cancel();

        if (context.mounted) {
          // Navigates to the root route which redirects to /login
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        }
      } catch (e) {
        debugPrint('Logout Error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }
}
