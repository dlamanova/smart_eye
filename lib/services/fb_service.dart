import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class FBService {
  // --- API Details (Fill these later) ---
  static const String baseUrl = 'https://us-central1-smarteye-b6322.cloudfunctions.net';

  /// Helper to get the current user's Firebase ID Token
  Future<String?> _getFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  /// POST /add_fcm_token - send FCM token to the server
  Future<bool> addFcmToken(String fcmToken) async {
    final token = await _getFirebaseIdToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_fcm_token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /add_server - add a new server to your account
  Future<bool> addServer(String name, String description, List<int> ip, int port, String secret) async {
    final token = await _getFirebaseIdToken();
    if (token == null) return false;

    Map<String, dynamic> body = {
      'name': name,
      'description': description,
      'ip': ip,
      'port': port,
      'secret': secret
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/addserver'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// GET /get_servers - get list of registered servers
  Future<List<Map<String, dynamic>>> getServers() async {
    final token = await _getFirebaseIdToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getservers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint("responce:" + response.body);
      debugPrint("responce:" + response.statusCode.toString());
      if (response.statusCode == 200) {
        debugPrint("Here!!");
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint("FBService.getServers: Full response data: $data");
        final List<dynamic> servers = data['servers'];
        debugPrint("FBService.getServers: Number of servers: ${servers.length}");
        for (int i = 0; i < servers.length; i++) {
          debugPrint("FBService.getServers: Server[$i]: ${servers[i]}");
          debugPrint("FBService.getServers: Server[$i] keys: ${(servers[i] as Map).keys.toList()}");
        }
        return servers.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint("Error 85: " + e.toString());
      return [];
    }
  }

  /// GET /get_token - retrieve an authentication token (from your API)
  /// Now expects serverId to be passed.
  Future<String?> getToken(String serverId) async {
    debugPrint('FBService.getToken: Starting for serverId: $serverId');
    final token = await _getFirebaseIdToken();
    if (token == null) {
      debugPrint('FBService.getToken: Firebase ID token is null');
      return null;
    }
    debugPrint('FBService.getToken: Firebase ID token obtained');

    try {
      // Send server_id as a query parameter
      final uri = Uri.parse('$baseUrl/get_janustoken').replace(queryParameters: {
        'server_id': serverId,
      });

      debugPrint('FBService.getToken: Making request to: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("FBService.getToken: Response status: ${response.statusCode}");
      debugPrint("FBService.getToken: Response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final janusToken = data['token'];
        debugPrint('FBService.getToken: Janus token extracted: $janusToken');
        // The API returns a JSON with a 'token' key
        return janusToken;
      }
      debugPrint('FBService.getToken: Non-200 response, returning null');
      return null;
    } catch (e) {
      debugPrint("FBService.getToken: Error: $e");
      return null;
    }
  }

  /// DELETE /deleteserver - delete a server by document ID
  Future<bool> deleteServer(String serverId) async {
    debugPrint('FBService.deleteServer: Starting for serverId: $serverId');
    final token = await _getFirebaseIdToken();
    if (token == null) {
      debugPrint('FBService.deleteServer: Firebase ID token is null');
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/deleteserver'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'document_id': serverId}),
      );

      debugPrint("FBService.deleteServer: Response status: ${response.statusCode}");
      debugPrint("FBService.deleteServer: Response body: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("FBService.deleteServer: Error: $e");
      return false;
    }
  }
}
