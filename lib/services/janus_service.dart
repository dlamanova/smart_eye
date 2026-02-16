import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// Service to handle communication with the Janus Gateway (VideoRoom Plugin)
class JanusService {
  static const String _pluginName = 'janus.plugin.videoroom';
  static const String janusServerUrl = 'http://192.168.1.11:8088/janus';

  String? _sessionId;
  String? _publisherHandleId;
  String? _subscriberHandleId;
  
  String? get publisherHandleId => _publisherHandleId;
  String? get subscriberHandleId => _subscriberHandleId;

  final int _roomId = 69;
  final String _roomPin = "1234"; // Default pin as requested

  int _transactionId = 0;
  String? _token; // Dynamic token from FBService

  Timer? _keepAliveTimer;
  Completer<void>? _sessionCompleter;
  bool _isPollingActive = false;

  StreamController<Map<String, dynamic>> _janusResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get janusResponses =>
      _janusResponseController.stream;

  /// Sets the authentication token for Janus requests.
  void setToken(String token) {
    _token = token;
    debugPrint('JanusService: Token set to: $_token');
  }

  // --- Core HTTP Methods ---

  Future<Map<String, dynamic>?> _sendPost(
    Map<String, dynamic> body, {
    String? specificHandleId,
  }) async {
    _transactionId++;
    body['transaction'] = 'tr${_transactionId.toString()}';
    
    debugPrint('JanusService: _token value before adding to body: $_token');
    // Use the dynamic token if available
    if (_token != null) {
      body['token'] = _token;
      debugPrint('JanusService: Token added to body');
    } else {
      debugPrint('JanusService: No token to add (token is null)');
    }

    final String _url = janusServerUrl;
    Uri url;
    if (_sessionId == null) {
      url = Uri.parse(_url);
    } else if (specificHandleId != null) {
      url = Uri.parse('$_url/$_sessionId/$specificHandleId');
    } else {
      url = Uri.parse('$_url/$_sessionId');
    }
    debugPrint('JanusService: POST to $url with body: $body');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (jsonResponse['janus'] == 'error') {
          debugPrint('JanusService: ERROR RESPONSE -> $jsonResponse');
        }
        return jsonResponse;
      } else {
        debugPrint('JanusService: HTTP POST ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('HTTP POST Exception: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _sendPollingGet() async {
    if (_sessionId == null) return null;
    
    String urlString = '$janusServerUrl/$_sessionId?maxev=1&rid=${DateTime.now().millisecondsSinceEpoch}&timeout=60000';
    if (_token != null) {
      urlString += '&token=$_token';
    }
    
    final url = Uri.parse(urlString);

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final janusType = jsonResponse['janus'] as String?;
        if (janusType == 'keepalive') return null;

        if (jsonResponse.containsKey('events')) {
          return (jsonResponse['events'] as List).cast<Map<String, dynamic>>();
        }
        if (janusType == 'event' || jsonResponse.containsKey('plugindata') || jsonResponse.containsKey('jsep')) {
          return [jsonResponse];
        }
      }
    } catch (e) {
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  void _startPolling() async {
    if (_sessionId == null || _isPollingActive) return;
    _isPollingActive = true;
    debugPrint('JanusService: Starting long-polling loop...');

    while (_isPollingActive) {
      final events = await _sendPollingGet();
      if (events != null) {
        for (final event in events) {
          if (!_janusResponseController.isClosed) {
            _janusResponseController.add(event);
          }
        }
      }
    }
    debugPrint('JanusService: Polling loop stopped.');
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isPollingActive || _sessionId == null) {
        timer.cancel();
        return;
      }
      _sendPost({'janus': 'keepalive'});
    });
  }

  // --- Public Interaction ---

  Future<void> connect() async {
    debugPrint('JanusService: Creating Session...');
    _sessionCompleter = Completer<void>();
    final response = await _sendPost({'janus': 'create'});

    if (response != null && response['janus'] == 'success') {
      _sessionId = response['data']['id'].toString();
      debugPrint('JanusService: Session $_sessionId created.');
      _sessionCompleter!.complete();
      _startPolling();
      _startKeepAlive();
    } else {
      throw Exception("Failed to create Janus session.");
    }
    await _sessionCompleter!.future;
  }

  Future<void> attachAsPublisher() async {
    if (_sessionId == null) throw Exception("Session not created");
    
    final resp = await _sendPost({'janus': 'attach', 'plugin': _pluginName});
    if (resp != null && resp['janus'] == 'success') {
      _publisherHandleId = resp['data']['id'].toString();
      debugPrint('JanusService: Publisher Handle $_publisherHandleId attached.');
    } else {
      throw Exception("Failed to attach publisher handle.");
    }
  }

  Future<Map<String, dynamic>?> joinRoomAsPublisher({String? display}) async {
    if (_publisherHandleId == null) throw Exception("No publisher handle");
    
    final body = {
      'request': 'join',
      'ptype': 'publisher',
      'room': _roomId,
      'pin': _roomPin, // Added pin
      'display': display ?? 'FlutterUser',
    };
    return await _sendPost({'janus': 'message', 'body': body}, specificHandleId: _publisherHandleId);
  }

  Future<Map<String, dynamic>?> subscribeToFeed(int feedId) async {
    debugPrint('JanusService: subscribeToFeed called for feedId: $feedId');

    if (_sessionId == null) {
      debugPrint('JanusService: ERROR - Session not created');
      throw Exception("Session not created");
    }

    if (_subscriberHandleId != null) {
      debugPrint('JanusService: Detaching old subscriber handle: $_subscriberHandleId');
      await _sendPost({'janus': 'detach'}, specificHandleId: _subscriberHandleId);
      _subscriberHandleId = null;
    }

    final attachResp = await _sendPost({'janus': 'attach', 'plugin': _pluginName});
    if (attachResp != null && attachResp['janus'] == 'success') {
      _subscriberHandleId = attachResp['data']['id'].toString();
      debugPrint('JanusService: ✓ Subscriber Handle $_subscriberHandleId attached.');
    } else {
      debugPrint('JanusService: ❌ Failed to attach subscriber handle. Response: $attachResp');
      throw Exception("Failed to attach subscriber handle.");
    }

    debugPrint('JanusService: Sending join request as subscriber for feed $feedId in room $_roomId');

    final body = {
      'request': 'join',
      'ptype': 'subscriber',
      'room': _roomId,
      'pin': _roomPin, // Added pin
      'streams': [
        {'feed': feedId}
      ],
    };

    debugPrint('JanusService: Subscriber join body: $body');

    final result = await _sendPost(
      {'janus': 'message', 'body': body},
      specificHandleId: _subscriberHandleId
    );

    debugPrint('JanusService: Subscriber join response: $result');
    return result;
  }

  Future<void> sendAnswer(RTCSessionDescription answer) async {
    if (_subscriberHandleId == null) {
      debugPrint('JanusService: ❌ Cannot send answer - no subscriber handle');
      throw Exception("No subscriber handle");
    }

    debugPrint('JanusService: Preparing to send SDP Answer to subscriber handle $_subscriberHandleId');
    debugPrint('JanusService: Answer type: ${answer.type}');
    debugPrint('JanusService: Answer SDP (first 300 chars): ${answer.sdp?.substring(0, answer.sdp!.length > 300 ? 300 : answer.sdp!.length)}');

    final body = {
      'request': 'start',
      'room': _roomId,
    };
    final msg = {
      'janus': 'message',
      'body': body,
      'jsep': {'type': answer.type, 'sdp': answer.sdp},
    };

    debugPrint('JanusService: Sending Answer with "start" request...');
    final result = await _sendPost(msg, specificHandleId: _subscriberHandleId);
    debugPrint('JanusService: Answer sent. Response: $result');
  }

  Future<void> sendTrickleCandidate(RTCIceCandidate? candidate) async {
    final targetHandle = _subscriberHandleId; 
    if (targetHandle == null) {
      debugPrint('JanusService: Cannot send ICE candidate - no subscriber handle');
      return;
    }

    final Map<String, dynamic> msg = {'janus': 'trickle'};
    if (candidate == null) {
      msg['candidate'] = {'completed': true};
    } else {
      msg['candidate'] = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };
    }
    await _sendPost(msg, specificHandleId: targetHandle);
  }

  Future<void> disconnect() async {
    _isPollingActive = false;
    _keepAliveTimer?.cancel();

    if (_subscriberHandleId != null) {
      await _sendPost({'janus': 'detach'}, specificHandleId: _subscriberHandleId);
      _subscriberHandleId = null;
    }

    if (_publisherHandleId != null) {
      await _sendPost({'janus': 'detach'}, specificHandleId: _publisherHandleId);
      _publisherHandleId = null;
    }

    if (_sessionId != null) {
      await Future.delayed(const Duration(milliseconds: 100));
      await _sendPost({'janus': 'destroy'});
      _sessionId = null;
    }
  }
}
