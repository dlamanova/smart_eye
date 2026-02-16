import 'package:flutter/material.dart';
import '/services/firebase_service.dart'; // Import FirebaseService

/// This class holds the logic, state, and data handling for the
/// Add Device screen. It extends ChangeNotifier to allow the UI to
/// listen for state updates.
class AddDeviceController extends ChangeNotifier {
  // Inject the FirebaseService dependency
  final FirebaseService _firebaseService;

  AddDeviceController(this._firebaseService);

  // --- UI State & Controllers (The "Logic" Data) ---
  final cameraNameController = TextEditingController();
  final cameraIdController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- Logic Methods ---

  /// Registers a new device in Firestore using the FirebaseService.
  Future<void> addCamera(BuildContext context) async {
    final name = cameraNameController.text.trim();
    final id = cameraIdController.text.trim();

    // Basic validation
    if (name.isEmpty || id.isEmpty) {
      _errorMessage = "Please enter both a Camera Name and a Unique Camera ID.";
      notifyListeners();
      return;
    }

    // Simple ID format validation
    if (id.length < 4) {
      _errorMessage = "ID must be at least 4 characters.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    try {
      // 1. Call the service layer to add the device to Firestore.
      await _firebaseService.addDevice(name: name, id: id);

      // 2. Success Feedback and Navigation
      // We will set a success message, notify, and then pop the context
      // back to the main dashboard.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera "$name" added successfully!')),
        );
        Navigator.pop(context); // Go back to MainPage
      }
    } catch (e) {
      // Handle Firebase/Firestore errors here
      _errorMessage = "Failed to add device: ${e.toString()}";
    } finally {
      // Only set isLoading to false if navigation didn't happen (i.e., error occurred)
      if (context.mounted && Navigator.canPop(context)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Dispose controllers to prevent memory leaks
  @override
  void dispose() {
    cameraNameController.dispose();
    cameraIdController.dispose();
    super.dispose();
  }
}
