import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // Add WebRTC import for RTCIceCandidate
import 'package:flutter/foundation.dart'; // Import for debugPrint
import '/features/devices/models/device_model.dart';

/// Centralized service class to handle all Firebase interactions (Auth and Firestore),
/// now including WebRTC signaling.
class FirebaseService {
  // Static instances for services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // WARNING: This assumes the __app_id is injected or set somewhere.
  // For a Flutter environment, you might fetch this from a config or set it globally.
  // We'll use a placeholder variable as a stand-in for the Canvas environment setup.
  final String appId = 'smarteye-app-b6322';

  // --- Utility Paths ---

  /// Returns the Firestore DocumentReference for the WebRTC signaling session.
  /// This path is PUBLIC as both the Viewer (Flutter) and the Streamer (RPi) need access.
  DocumentReference _webRTCSessionDocRef(String sessionId) {
    // Path: /artifacts/{appId}/public/data/webrtc_sessions/{sessionId}
    return _firestore.doc(
      'artifacts/$appId/public/data/webrtc_sessions/$sessionId',
    );
  }

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

  // --- Firestore Device Management (Private Data) ---

  // ... (Existing Device Management methods remain the same) ...

  /// Adds a new device document to the current user's collection.
  Future<void> addDevice({required String name, required String id}) async {
    final userId = currentUser?.uid;

    if (userId == null) {
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

  // --- WebRTC Signaling Methods (Public Data) ---

  /// Creates a new WebRTC session document and stores the initial Offer SDP.
  Future<void> createWebRTCSession(
    String sessionId,
    Map<String, dynamic> offer,
  ) async {
    final docRef = _webRTCSessionDocRef(sessionId);

    await docRef.set({
      'offer': offer,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams the WebRTC session document to listen for the remote Answer SDP.
  Stream<Map<String, dynamic>?> streamWebRTCSession(String sessionId) {
    final docRef = _webRTCSessionDocRef(sessionId);

    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return snapshot.data() as Map<String, dynamic>;
    });
  }

  /// Sends an ICE candidate to the signaling document.
  ///
  /// The candidates are stored in subcollections depending on whether the candidate
  /// is from the Offer creator (viewer) or the Answer creator (streamer).
  Future<void> sendIceCandidate(
    String sessionId,
    Map<String, dynamic> candidateMap, {
    required bool isOfferCandidate,
  }) async {
    final docRef = _webRTCSessionDocRef(sessionId);
    // Use different subcollections to prevent feedback loops:
    // 'offerCandidates' for candidates from the device that created the Offer (Viewer/Flutter)
    // 'answerCandidates' for candidates from the device that created the Answer (Streamer/RPi)
    final collectionName = isOfferCandidate
        ? 'offerCandidates'
        : 'answerCandidates';

    await docRef.collection(collectionName).add(candidateMap);
  }

  /// Streams the remote peer's ICE candidates (Answer Candidates in this setup).
  Stream<Map<String, dynamic>?> streamRemoteIceCandidates(String sessionId) {
    final docRef = _webRTCSessionDocRef(sessionId);
    // Flutter (Viewer) created the Offer, so it listens for the Streamer's (RPi's) Answer Candidates.
    final collectionRef = docRef.collection('answerCandidates');

    return collectionRef.snapshots().map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Pop the first candidate and delete it immediately to prevent reprocessing
        final doc = snapshot.docs.first;
        doc.reference.delete();
        return doc.data();
      }
      return null;
    });
  }

  Future<void> initNotifications() async {
    // Request permission (iOS will show prompt)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    // On iOS ensure APNs token is available before calling getToken()
    if (Platform.isIOS) {
      // Wait briefly for native to register and forward APNs token. Retry a few times.
      String? apns;

      for (int i = 0; i < 1; i++) {
        try {
          apns = await _messaging.getAPNSToken();
          debugPrint('Trying to get APNs token, attempt ${i + 1}, result: $apns');
        } catch (e) {
          debugPrint('getAPNSToken error (ignored): $e');
        }
        if (apns != null && apns.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 300));
      }
      debugPrint('APNs token: $apns');
    }

    // Now try to get the FCM token. Wrap in try/catch to avoid unhandled exceptions.
    try {
      final String? token = await _messaging.getToken();
      debugPrint('Firebase Messaging Token: $token');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received a foreground message: ${message.messageId}');
      if (message.notification != null) {
        debugPrint('Notification: ${message.notification}');
      }
    });

    // Optionally handle background/tapped messages with onBackgroundMessage and onMessageOpenedApp
  }
}
