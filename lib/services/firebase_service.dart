import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/features/devices/models/device_model.dart';

/// Centralized service class to handle all Firebase interactions (Auth and Firestore).
class FirebaseService {
  // Static instances for services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // WARNING: This assumes the __app_id is injected or set somewhere.
  // For a Flutter environment, you might fetch this from a config or set it globally.
  // We'll use a placeholder variable as a stand-in for the Canvas environment setup.
  final String appId = 'smarteye-app-b6322';

  // --- Authentication Methods ---

  /// Returns the currently logged-in user.
  User? get currentUser => _auth.currentUser;

  /// Signs in a user with email and password.
  Future<UserCredential> signIn(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new user with email and password.
  Future<UserCredential> signUp(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Firestore Device Management ---

  /// Adds a new device document to the current user's collection.
  Future<void> addDevice({required String name, required String id}) async {
    final userId = currentUser?.uid;

    // FIX: Check for user authentication before attempting Firestore write.
    if (userId == null) {
      // Throw a standard StateError when no user is logged in
      throw StateError(
        'User must be logged in to add a device. Please log in first.',
      );
    }

    // Use the standard secure path: artifacts/{appId}/users/{userId}/devices/{deviceId}
    final deviceRef = _firestore
        .collection('artifacts/$appId/users/$userId/devices')
        .doc(id);

    await deviceRef.set({
      'id': id,
      'name': name,
      'owner': userId, // Store the owner's ID
      'isOnline': false,
      'isPoweredOn': false,
      'isMotionDetectionEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams a list of all devices owned by the current user.
  Stream<List<DeviceModel>> streamUserDevices() {
    final userId = currentUser?.uid;
    if (userId == null) {
      // If no user is logged in, return an empty stream
      return Stream.value([]);
    }

    // Reference the user's private devices collection
    final collectionRef = _firestore.collection(
      'artifacts/$appId/users/$userId/devices',
    );

    return collectionRef.snapshots().map((snapshot) {
      // Map each document to a DeviceModel
      return snapshot.docs.map((doc) {
        return DeviceModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Streams the data for a single specific device.
  Stream<DeviceModel?> streamDevice(String deviceId) {
    final userId = currentUser?.uid;
    if (userId == null) {
      return Stream.value(null);
    }

    // Reference the specific device document
    final docRef = _firestore.doc(
      'artifacts/$appId/users/$userId/devices/$deviceId',
    );

    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      // Map the document data to a DeviceModel
      return DeviceModel.fromFirestore(snapshot.data()!, snapshot.id);
    });
  }

  /// Updates specific fields on a device document.
  Future<void> updateDeviceState(
    String deviceId,
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.uid;
    if (userId == null) {
      throw StateError('User must be logged in to update device state.');
    }

    final docRef = _firestore.doc(
      'artifacts/$appId/users/$userId/devices/$deviceId',
    );
    await docRef.update(updates);
  }
}
