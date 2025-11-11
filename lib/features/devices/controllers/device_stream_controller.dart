import 'dart:async';
import 'package:flutter/material.dart';
import '/features/devices/models/device_model.dart';
import '/services/firebase_service.dart';

class DeviceStreamController extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final String _deviceId;
  late final StreamSubscription<DeviceModel?> _deviceSubscription;

  // --- State ---
  DeviceModel? _device;
  String? _errorMessage;
  bool _isToggling = false; // Prevents spamming Firebase updates

  DeviceModel? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get isToggling => _isToggling;

  DeviceStreamController(this._firebaseService, this._deviceId) {
    // Start listening to the single device's state
    _deviceSubscription = _firebaseService
        .streamDevice(_deviceId)
        .listen(
          (device) {
            // Success case: process the new device data
            _device = device;
            if (device == null) {
              _errorMessage = "Device with ID $_deviceId not found.";
            } else {
              _errorMessage = null; // Clear error if device is found
            }
            notifyListeners();
          },
          // Error case: Handle the error using the named 'onError' parameter
          onError: (error) {
            _errorMessage = "Failed to stream device: $error";
            notifyListeners();
          },
        );
  }

  // --- Control Methods ---

  /// Helper method to safely update state in Firebase
  Future<void> _updateState(Map<String, dynamic> updates) async {
    if (_isToggling) return; // Prevent concurrent updates

    _isToggling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.updateDeviceState(_deviceId, updates);
    } catch (e) {
      _errorMessage = "Failed to update device state: $e";
    } finally {
      // isToggling is reset regardless of success/failure
      _isToggling = false;
      notifyListeners();
    }
  }

  /// Toggles the device power state (isPoweredOn).
  Future<void> togglePower() async {
    if (_device == null) return;
    await _updateState({'isPoweredOn': !_device!.isPoweredOn});
  }

  /// Toggles the device motion detection state (isMotionDetectionEnabled).
  Future<void> toggleMotionDetection() async {
    if (_device == null) return;
    await _updateState({
      'isMotionDetectionEnabled': !_device!.isMotionDetectionEnabled,
    });
  }

  @override
  void dispose() {
    _deviceSubscription.cancel();
    super.dispose();
  }
}
