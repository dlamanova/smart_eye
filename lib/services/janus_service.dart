import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

/// Service to handle communication with the Janus Gateway
class JanusService {
  static const String janusServerUrl = 'http://192.168.1.84:8088/janus';
  // static const String janusAdminUrl = 'http://192.168.1.10:7088/janusx/admin';

  String? _sessionId;
  String? _handleId;
  final int _streamId = 1;

  // --- FIX: Declare transaction ID here as a private class member ---
  int _transactionId = 0;
  // -----------------------------------------------------------------

  // Timers and controllers for HTTP polling and keep-alive
  Timer? _keepAliveTimer;
  Completer<void>? _sessionCompleter;
  Completer<void>? _handleCompleter;
  bool _isPollingActive = false; // Flag to control the polling loop

  // allow recreation after being closed
  StreamController<Map<String, dynamic>> _janusResponseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get janusResponses =>
      _janusResponseController.stream;

  // --- Core HTTP Methods ---

  /// Sends a POST request to Janus and returns the response body.
  Future<Map<String, dynamic>?> _sendPost(
    Map<String, dynamic> body, {
    bool isAdmin = false,
    String? specificHandleId,
  }) async {
    _transactionId++;
    body['transaction'] = 'tr${_transactionId.toString()}';

    // Construct the full URL
    final String _url = janusServerUrl;

    try {
      Uri url;
      if (_sessionId == null) {
        // Creating a session uses the base URL
        url = Uri.parse(_url);
      } else if (specificHandleId != null) {
        // POST to /janus/{session}/{handle}
        url = Uri.parse('$_url/$_sessionId/$specificHandleId');
      } else {
        // POST to /janus/{session}
        url = Uri.parse('$_url/$_sessionId');
      }
      debugPrint('JanusService: POST to $url with body: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('JanusService: POST $url -> $jsonResponse');
        return jsonResponse;
      } else {
        debugPrint('JanusService: HTTP POST ${response.statusCode} for $url');
        return null;
      }
    } catch (e) {
      debugPrint('HTTP POST Exception: $e');
      return null;
    }
  }

  /// Sends the long-polling GET request.
  Future<List<Map<String, dynamic>>?> _sendPollingGet() async {
    if (_sessionId == null) return null;

    // The GET polling URL uses the session ID only
    // Use the maximum timeout (60 seconds) for efficiency
    // NOTE: Do NOT exclude the handle; doing so prevents Janus from sending
    //plugin events (SDP offers / ICE candidates) for that handle.
    final url = Uri.parse(
      '$janusServerUrl/$_sessionId?maxev=1&rid=${DateTime.now().millisecondsSinceEpoch}&timeout=60000',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('JanusService: Poll GET response: $jsonResponse');

        final janusType = jsonResponse['janus'] as String?;
        if (janusType == 'keepalive') {
          return null; // Ignore keep-alive responses from polling
        }

        // Scenario 1: Multiple events bundled in the 'events' array (most common for SDP Offer/Candidates)
        if (jsonResponse.containsKey('events')) {
          return (jsonResponse['events'] as List).cast<Map<String, dynamic>>();
        }

        // Scenario 2: Immediate success response or an event/SDP Offer not in an array (e.g., janus: event)
        if (janusType == 'event' || jsonResponse.containsKey('plugindata')) {
          return [jsonResponse];
        }
      }
    } catch (e) {
      // Catching expected Timeouts or actual network failures
      // We don't need to print every timeout, only serious exceptions
      // debugPrint('HTTP GET Polling Exception: $e');
    }
    return null;
  }

  // --- Session Management ---

  /// Starts the long-polling loop to listen for Janus events.
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

      // Removed the fixed delay (Duration(milliseconds: 50))
      // The HTTP GET call is a long-poll and already blocks for up to 60 seconds
      // A small delay is only needed to prevent a rapid fire loop if the server
      // immediately returns without blocking, but 50ms is too fast.
      // Let's rely on the 60-second timeout of the GET request.
    }
    debugPrint('JanusService: Polling loop stopped.');
  }

  /// Starts a timer to send keep-alive messages every 30 seconds.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isPollingActive || _sessionId == null) {
        timer.cancel();
        return;
      }
      // Send a simple keep-alive message
      _sendPost({'janus': 'keepalive'});
      debugPrint('JanusService: Sent Keep-Alive.');
    });
  }

  // --- Public Janus Interaction ---

  /// Establishes the HTTP connection, starts the Janus session, and starts polling.
  Future<void> connect() async {
    debugPrint('JanusService: Attempting HTTP session creation...');
    _sessionCompleter = Completer<void>();

    // 1. Create a new Janus session (POST /janus)
    final response = await _sendPost({'janus': 'create'});

    if (response != null && response['janus'] == 'success') {
      _sessionId = response['data']['id'].toString();
      debugPrint('JanusService: Session $_sessionId created.');
      _sessionCompleter!.complete();

      // 2. Start Polling for events immediately
      _startPolling();

      // 3. Start Keep-Alive timer
      _startKeepAlive();
    } else {
      throw Exception("Failed to create Janus session via HTTP.");
    }

    // Wait for the session ID to be set before proceeding
    await _sessionCompleter!.future;
  }

  /// Sends the WebRTC SDP Answer back to Janus.
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    if (_handleId == null) {
      throw Exception(
        "Janus handle not attached when attempting to send Answer.",
      );
    }

    // Ensure the SDP Answer includes DTLS and ICE configurations
    final answerMessage = {
      'janus': 'message',
      'body': {
        'request': 'start', // Send 'start' with the Answer to begin streaming
      },
      'jsep': {'type': answer.type, 'sdp': answer.sdp},
    };

    debugPrint('JanusService: Sending SDP Answer back to Janus...');
    debugPrint('JanusService: Answer Message: $answerMessage');

    final response = await _sendPost(
      answerMessage,
      specificHandleId: _handleId,
    );
    debugPrint('JanusService: sendAnswer response: $response');
    if (response == null || response['janus'] != 'ack') {
      throw Exception("Failed to send SDP Answer to Janus.");
    }
  }

  /// Attaches to the Streaming Plugin and requests to watch the stream.
  Future<void> attachAndWatchStream() async {
    if (_sessionId == null) {
      throw Exception("Janus session not initialized.");
    }

    _handleCompleter = Completer<void>();

    // 1. Attach to the Streaming Plugin (POST /janus/{session_id})
    debugPrint('JanusService: Attaching to Streaming Plugin...');
    final attachResponse = await _sendPost({
      'janus': 'attach',
      'plugin': 'janus.plugin.streaming',
    });

    debugPrint('JanusService: attachResponse: $attachResponse');
    if (attachResponse != null && attachResponse['janus'] == 'success') {
      // Handle ID should be in the response data for HTTP
      _handleId = attachResponse['data']['id'].toString();
      debugPrint(
        'JanusService: Handle $_handleId attached to Streaming Plugin.',
      );
      _handleCompleter!.complete();
    } else {
      throw Exception("Failed to attach to Janus Streaming Plugin.");
    }

    // Wait for handle ID (which happens synchronously for HTTP POST)
    await _handleCompleter!.future;

    // 2. Send the 'watch' command (POST /janus/{session_id}/{handle_id})
    debugPrint('JanusService: Sending watch request for stream $_streamId...');
    final watchResponse = await _sendPost({
      'janus': 'message',
      'body': {'request': 'watch', 'id': _streamId},
    }, specificHandleId: _handleId);

    debugPrint('JanusService: watchResponse: $watchResponse');
    if (watchResponse == null || watchResponse['janus'] != 'ack') {
      throw Exception("Failed to send watch command to Janus.");
    }
    debugPrint('JanusService: Watch command sent successfully.');
  }

  /// Sends a trickled ICE candidate. If [candidate] is null, send the
  /// "completed" trickle ({"candidate": {"completed": true}}) to signal end
  /// of local gathering to Janus.
  Future<void> sendTrickleCandidate(RTCIceCandidate? candidate) async {
    if (_handleId == null) return;

    final Map<String, dynamic> trickleMessage = {'janus': 'trickle'};

    if (candidate == null) {
      trickleMessage['candidate'] = {'completed': true};
    } else {
      trickleMessage['candidate'] = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };
    }

    debugPrint('JanusService: Sending trickle -> $trickleMessage');
    final resp = await _sendPost(trickleMessage, specificHandleId: _handleId);
    debugPrint('JanusService: sendTrickle response: $resp');
  }

  /// Gracefully detach handle (if any), destroy session, and stop polling/keep-alive.
  Future<void> disconnect() async {
    // stop polling immediately and cancel keep-alive
    _isPollingActive = false;
    _keepAliveTimer?.cancel();

    final currentHandle = _handleId;
    final currentSession = _sessionId;
    if (currentSession == null) return;

    if (currentHandle != null) {
      try {
        final detachResp = await _sendPost({
          'janus': 'detach',
        }, specificHandleId: currentHandle);
        debugPrint('JanusService: detach response: $detachResp');
      } catch (e) {
        debugPrint('JanusService: detach error: $e');
      }
      _handleId = null;
    }

    // Give Janus a short moment to process detach
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final destroyResp = await _sendPost({'janus': 'destroy'});
      debugPrint('JanusService: destroy response: $destroyResp');
    } catch (e) {
      debugPrint('JanusService: destroy error: $e');
    }

    // Do NOT close the _janusResponseController here — keep it available for future connect() calls.
    _sessionId = null;
  }

  /// Ensure the internal response controller is available (recreate if closed).
  void _ensureResponseController() {
    if (_janusResponseController.isClosed) {
      _janusResponseController =
          StreamController<Map<String, dynamic>>.broadcast();
    }
  }

  Future<void> toggleMotionDetection(bool enable) async {
    if (_handleId == null) {
      throw Exception(
        "Janus handle not attached when attempting to toggle motion detection.",
      );
    }

    final motionMessage = {
      'janus': 'custom_event',
      'body': {'request': enable ? 'enable_motion' : 'disable_motion'},
    };

    debugPrint(
      'JanusService: Sending motion detection toggle -> $motionMessage',
    );

    final response = await _sendPost(
      motionMessage,
      specificHandleId: _handleId,
      isAdmin: true,
    );
    debugPrint('JanusService: toggleMotionDetection response: $response');
    if (response == null || response['janus'] != 'ack') {
      throw Exception("Failed to toggle motion detection on Janus.");
    }
  }
}
