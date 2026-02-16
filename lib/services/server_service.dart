import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ServerService {
  // static const String apiToken = 'YOUR_API_TOKEN_HERE';


  /// GET /health - Check if server is healthy
  Future<bool> checkHealth(List<int> ip, int port) async {

    String baseUrl = 'http://${ip.join('.')}:$port';

    debugPrint('ServerService: Checking health at $baseUrl/health...');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {
          // 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      final isHealthy = response.statusCode == 200;
      debugPrint('ServerService: Health check result -> ${isHealthy ? "SUCCESS (200 OK)" : "FAILURE (${response.statusCode})"}');
      return isHealthy;
    } catch (e) {
      debugPrint('ServerService: Health check FAILED with exception: $e');
      return false;
    }
  }

  /// GET /get_cameras - Get cameras list
  /// Returns a list of maps, each containing: name, description, uuid, is_new
  Future<List<Map<String, dynamic>>> getCameras(List<int> ip, int port) async {
    String baseUrl = 'http://${ip.join('.')}:$port';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_cameras'),
        headers: {
          // 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('ServerService: Error fetching cameras: $e');
      return [];
    }
  }

  Future<String?> setServerId(List<int> ip, int port, String serverId) async {
    String baseUrl = 'http://${ip.join('.')}:$port/set_server_id';
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          // 'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'server_id': serverId}),
      );

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }




  /// POST /janus - Placeholder for Janus related requests
  // Future<Map<String, dynamic>?> janusRequest(Map<String, dynamic> body) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/janus'),
  //       headers: {
  //         // 'Authorization': 'Bearer $apiToken',
  //         'Content-Type': 'application/json',
  //       },
  //       body: jsonEncode(body),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     }
  //     return null;
  //   } catch (e) {
  //     return null;
  //   }
  // }

  /// PUT /camera/{uuid} - Update camera details
  Future<bool> updateCamera(List<int> ip, int port, String uuid, Map<String, dynamic> details) async {
    String baseUrl = 'http://${ip.join('.')}:$port';
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/camera/$uuid'),
        headers: {
          // 'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(details),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}