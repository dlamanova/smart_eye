import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:http/http.dart' as http; // Add http import
import '../models/notification.dart';
import '../models/server.dart'; // Add import for Server model

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
  Future<UserCredential> login(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new user with email and password.
  Future<UserCredential> register(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Deletes the current user account.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    } else {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user signed in.',
      );
    }
  }

  /// Updates the current user's profile information.
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
    } else {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user signed in.',
      );
    }
  }

  /// Updates the current user's email address.
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
    } else {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user signed in.',
      );
    }
  }

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user signed in.',
      );
    }
  }

  // --- Firestore Server Management ---

  /// Sends server data to the external API instead of saving to Firestore.
  /// Pin is stored locally (or not sent), and Authorization header is used.
  Future<void> addServer({
    required String name,
    required String description,
    required List<int> ip,
    required int port,
    required String secret,
    required String pin,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw StateError(
        'User must be logged in to add a server. Please log in first.',
      );
    }

    final String? token = await user.getIdToken();
    if (token == null) {
      throw StateError('Could not retrieve user authentication token.');
    }

    // Placeholder URL for the addserver endpoint
    final Uri url = Uri.parse('YOUR_ADD_SERVER_ENDPOINT_HERE');

    // Construct the request body
    // Note: 'pin' is NOT included in the request body as per requirements.
    final Map<String, dynamic> body = {
      'name': name,
      'description': description,
      'ip': ip,
      'port': port,
      'secret': secret,
      // 'id' is requested to be sent, but we don't have a server ID yet as this is a creation request.
      // Usually the server would return the ID. If you need to generate one client-side:
      // 'id': _firestore.collection('dummy').doc().id, // Example if client-side ID generation is needed
    };

    // If the API expects an 'id' field even for new entries (client-generated ID), uncomment below:
    // body['id'] = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Server added successfully via API: ${response.body}');

        // Optionally save the PIN locally here using SharedPreferences or secure storage if needed
        // await SecureStorage.savePin(pin);
      } else {
        throw HttpException(
          'Failed to add server. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error sending server data to API: $e');
      rethrow; // Re-throw to be handled by the UI
    }
  }

  // --- Server Retrieval (API / Placeholder) ---

  /// Fetches the list of servers from the API.
  Future<List<Server>> fetchServers() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final token = await user.getIdToken();
      // Placeholder API call
      final Uri url = Uri.parse('YOUR_GET_SERVERS_ENDPOINT_HERE');

      // Simulate network request
      // final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      // if (response.statusCode == 200) { ... parse json ... }

      // For now, return placeholder data as requested
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Simulate latency
      return [
        Server(
          id: 'server_1',
          name: 'Home Server',
          description: 'Raspberry Pi 4 - Living Room',
          ip: [192, 168, 1, 11],
          port: 5000,
          secret: 'janus_secret_1',
          pin: '1234',
        ),
        Server(
          id: 'server_2',
          name: 'Office Server',
          description: 'Ubuntu Server - Office',
          ip: [10, 0, 0, 50],
          port: 8188,
          secret: 'janus_secret_2',
          pin: '5678',
        ),
      ];
    } catch (e) {
      debugPrint('Error fetching servers: $e');
      return [];
    }
  }

  /// Streams user servers. Currently backed by fetchServers (one-time fetch converted to stream).
  Stream<List<Server>> streamUserServers() async* {
    yield await fetchServers();
  }

  // --- Firestore Device Management (Private Data) ---

  /// Adds a new device document to the current user's collection.
  Future<void> addDevice({
    required String name,
    required String id,
    String? serverId,
  }) async {
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

    // In a real implementation with servers, you might also link the device to the server
    // e.g., artifacts/$appId/users/$userId/servers/$serverId/devices/$id
    // For now, we just add the serverId to the device metadata if provided.

    await deviceRef.set({
      'id': id,
      'name': name,
      'owner': userId, // Store the owner's ID
      'serverId': serverId, // Link to server
      'isOnline': false,
      'isPoweredOn': false,
      'isMotionDetectionEnabled': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Streams a list of all devices owned by the current user.
  /// Modified to optionally filter or just fetch all.
  /// The UI then maps these devices to the servers.

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

  // --- Notification Methods ---

  /// Streams user notifications from Firestore.
  Stream<List<NotificationItem>> streamNotifications() {
    final userId = currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('artifacts/$appId/users/$userId/notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return NotificationItem(
              id: doc.id,
              title: data['title'] ?? '',
              message: data['message'] ?? '',
              timestamp: _formatTimestamp(data['timestamp']),
              type: _parseNotificationType(data['name']),
              isRead: data['isRead'] ?? false,
            );
          }).toList();
        });
  }

  /// Adds a new notification to Firestore (for testing or backend triggers).
  Future<void> addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
  }) async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('artifacts/$appId/users/$userId/notifications')
        .add({
          'title': title,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': type.toString().split('.').last,
          'isRead': false,
        });
  }

  /// Marks a specific notification as read.
  Future<void> markNotificationAsRead(String notificationId) async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .doc('artifacts/$appId/users/$userId/notifications/$notificationId')
        .update({'isRead': true});
  }

  /// Marks a specific notification as unread.
  Future<void> markNotificationAsUnread(String notificationId) async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .doc('artifacts/$appId/users/$userId/notifications/$notificationId')
        .update({'isRead': false});
  }

  /// Marks all unread notifications as read.
  Future<void> markAllNotificationsAsRead() async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('artifacts/$appId/users/$userId/notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(String notificationId) async {
    final userId = currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .doc('artifacts/$appId/users/$userId/notifications/$notificationId')
        .delete();
  }

  // Helper: Format Firestore Timestamp to String
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final now = DateTime.now();
      final date = timestamp.toDate();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} minutes ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hours ago';
      } else {
        return '${diff.inDays} days ago';
      }
    }
    return 'Just now';
  }

  // Helper: Parse NotificationType from String
  NotificationType _parseNotificationType(String? typeStr) {
    return NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => NotificationType.info,
    );
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
          debugPrint(
            'Trying to get APNs token, attempt ${i + 1}, result: $apns',
          );
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
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification}',
        );
        addNotification(
          title: message.notification!.title ?? 'Event',
          message: message.notification!.body ?? 'No message',
        );
      }
    });
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
