import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import '/features/devices/models/device_model.dart';
import '/services/firebase_service.dart';
import '/services/janus_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Controller responsible for managing the device state and the WebRTC video stream.
class DeviceStreamController extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final JanusService _janusService;
  final String _deviceId;

  late final StreamSubscription<DeviceModel?> _deviceSubscription;
  StreamSubscription? _janusResponseSubscription;

  // --- Device State ---
  DeviceModel? _device;
  String? _errorMessage;
  bool _isToggling = false;

  DeviceModel? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get isToggling => _isToggling;

  // --- WebRTC State ---
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _remoteStream;

  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  // --- WebRTC Configuration ---
  // Provide a STUN server so the emulator can gather server-reflexive candidates
  // (which are reachable from Janus on the LAN). Add TURN if you need relays.
  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      // Example TURN (uncomment & fill if you run a TURN server):
      // {
      //   'urls': 'turn:your.turn.server:3478',
      //   'username': 'user',
      //   'credential': 'pass',
      // },
    ],
    'iceTransportPolicy': 'all',
  };



  // Constructor
  DeviceStreamController(
    this._firebaseService,
    this._janusService,
    this._deviceId,
  ) {
    clientSupportsH264()
        .then((supportsH264) {
          debugPrint('Client H264 support: $supportsH264');
        })
        .catchError((e) {
          debugPrint('Error checking H264 support: $e');
        });
    _initRenderers();
    _deviceSubscription = _firebaseService
        .streamDevice(_deviceId)
        .listen(
          (device) {
            _device = device;
            if (device == null) {
              _errorMessage = "Device with ID $_deviceId not found.";
            } else {
              _errorMessage = null;
            }
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = "Failed to stream device: $error";
            notifyListeners();
          },
        );

    // Start WebRTC session setup via Janus
    _startWebRTCSession();
  }

  // --- Initialization & Disposal ---

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _deviceSubscription.cancel();
    _janusResponseSubscription?.cancel();
    // Ask JanusService to detach/destroy session properly
    _janusService.disconnect().catchError((e) {
      debugPrint('Error disconnecting JanusService: $e');
    });

    // Clean up WebRTC objects
    _peerConnection?.close();
    _peerConnection = null;
    _remoteStream = null;
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();

    super.dispose();
  }

  /// Connects to the Janus stream and (re)starts the WebRTC session.
  Future<void> connectToStream() async {
    try {
      await _initRenderers();
      await _startWebRTCSession();
      notifyListeners();
    } catch (e) {
      debugPrint('Error connecting to stream: $e');
      _errorMessage = 'Failed to connect to stream: $e';
      notifyListeners();
    }
  }

  /// Disconnects from the Janus stream and tears down local WebRTC objects.
  Future<void> disconnectFromStream() async {
    // Cancel any Janus response subscription for this controller
    try {
      await _janusResponseSubscription?.cancel();
    } catch (_) {}
    _janusResponseSubscription = null;

    // Request Janus to detach/destroy the session for this handle
    try {
      await _janusService.disconnect();
    } catch (e) {
      debugPrint('JanusService.disconnect error: $e');
    }

    // Close and null out the peer connection
    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    // Clear renderer / local stream
    _remoteStream = null;
    try {
      _remoteRenderer.srcObject = null;
    } catch (_) {}

    notifyListeners();
  }

  /// Convenience toggle: disconnect if connected, otherwise connect.
  Future<void> toggleStreamConnection() async {
    final isStreaming = _remoteRenderer.srcObject != null;
    if (isStreaming) {
      await disconnectFromStream();
    } else {
      await connectToStream();
    }
  }

  // --- WebRTC Streaming Logic ---

  Future<void> _startWebRTCSession() async {
    // 1. Connect to Janus Gateway and establish session (Now uses HTTP POST/GET)
    try {
      await _janusService.connect();
    } catch (e) {
      _errorMessage = "Failed to connect to Janus Gateway: $e";
      notifyListeners();
      return;
    }

    // 2. Create the Peer Connection
    _peerConnection = await createPeerConnection(_iceServers, {});
    debugPrint('PeerConnection created.');

    // Log connection / signaling state for DTLS/ICE debug
    _peerConnection?.onIceConnectionState = (state) {
      debugPrint('PeerConnection ICE state: $state');
    };
    // Some platforms expose overall connection state
    _peerConnection?.onConnectionState = (state) {
      debugPrint('PeerConnection connection state: $state');
    };
    _peerConnection?.onSignalingState = (state) {
      debugPrint('PeerConnection signaling state: $state');
    };
    _peerConnection?.onIceGatheringState = (state) {
      debugPrint('PeerConnection ICE gathering state: $state');
    };

    // 3. Setup remote track listener
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty && event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
        _remoteStream = event.streams[0];
        debugPrint('Remote stream track received and attached to renderer.');
        notifyListeners();
      }};

    // 4. Setup local ICE candidate sender
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate != null) {
        debugPrint(
          'Local ICE candidate generated: ${candidate.candidate} sdpMid=${candidate.sdpMid} sdpMLineIndex=${candidate.sdpMLineIndex}',
        );

        // Filter out obvious loopback candidates from the emulator so we don't
        // send localhost to Janus. Keep candidates like srflx/relay.
        final candStr = candidate.candidate ?? '';
        final isLoopback = candStr.contains('127.0.0.1') || candStr.contains('::1');
        if (isLoopback) {
          debugPrint('Skipping loopback ICE candidate (not sending to Janus): $candStr');
          return;
        }

        // Send generated ICE Candidates to Janus via the service
        _janusService.sendTrickleCandidate(candidate).catchError((e) {
          debugPrint('Error sending trickle candidate to Janus: $e');
        });
      } else {
        // Some platforms signal end-of-candidates with a null candidate
        debugPrint(
          'Local ICE gathering completed (null candidate). Sending completed trickle.',
        );
        _janusService.sendTrickleCandidate(null);
      }
    };

    // 5. Listen to Janus messages for the SDP Offer and Candidates
    // This stream is now fed by the HTTP Long-Polling loop in JanusService.
    _janusResponseSubscription = _janusService.janusResponses.listen(
      (json) async {
        final jsep = json['jsep'] as Map<String, dynamic>?;
        final janusType = json['janus'] as String?;

        // --- A. Handle JSEP (SDP Offer) ---
        if (jsep != null) {
          final type = jsep['type'] as String?;
          final sdp = jsep['sdp'] as String?;

          if (type == 'offer' && sdp != null && _peerConnection != null) {
            try {
              debugPrint('Received SDP Offer from Janus. Processing...');
              // Apply remote description (the Offer)
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(sdp, type),
              );
              debugPrint('Remote description set.');

              // Create Answer
              final answer = await _peerConnection!.createAnswer({});
              // DEBUG: log the local answer SDP (including local fingerprint)
              debugPrint(
                'Local SDP Answer (first 1000 chars): ${answer.sdp?.substring(0, answer.sdp!.length > 1000 ? 1000 : answer.sdp!.length)}',
              );
              debugPrint('Local SDP Answer created.');

              // Set local description (the Answer) before sending to Janus
              await _peerConnection!.setLocalDescription(answer);
              debugPrint('Local description set. Sending Answer to Janus...');

              // Send Answer to Janus
              await _janusService.sendAnswer(answer);
              debugPrint('SDP Answer sent to Janus.');

              // Ensure Janus receives the end-of-candidates signal if local gathering finished.
              // Wait a short moment for any remaining local candidates, then send completed trickle.
              await Future.delayed(const Duration(milliseconds: 250));
              debugPrint('Sending completed trickle to Janus (explicit).');
              await _janusService.sendTrickleCandidate(null);
            } catch (e, st) {
              debugPrint('Error handling SDP offer/answer flow: $e\n$st');
              _errorMessage = 'WebRTC SDP handling error: $e';
              notifyListeners();
            }
          }
        }

        // --- B. Handle Trickled ICE candidates from Janus ---
        final candidateJson = json['candidate'] as Map<String, dynamic>?;
        if (janusType == 'trickle' && candidateJson != null) {
          try {
            debugPrint('Received ICE Candidate from Janus: $candidateJson');
            final cand = RTCIceCandidate(
              candidateJson['candidate'] as String?,
              candidateJson['sdpMid'] as String?,
              candidateJson['sdpMLineIndex'] as int?,
            );
            await _peerConnection?.addCandidate(cand);
            debugPrint('Added remote ICE candidate to PeerConnection.');
          } catch (e) {
            debugPrint('Error adding remote ICE candidate: $e');
          }
        }
      },
      onError: (error) {
        _errorMessage = "Janus signaling error: $error";
        notifyListeners();
      },
    );

    // 6. Attach to the plugin and send the 'watch' request.
    await _janusService.attachAndWatchStream();
  }

  // --- Control Methods (Existing Logic) ---

  Future<void> _updateState(Map<String, dynamic> updates) async {
    if (_isToggling) return;

    _isToggling = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.updateDeviceState(_deviceId, updates);
    } catch (e) {
      _errorMessage = "Failed to update device state: $e";
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  Future<void> togglePower() async {
    if (_device == null) return;
    await _updateState({'isPoweredOn': !_device!.isPoweredOn});
  }

  Future<void> toggleMotionDetection() async {
    if (_device == null) return;
    _janusService.toggleMotionDetection(!_device!.isMotionDetectionEnabled);
    await _updateState({
      'isMotionDetectionEnabled': !_device!.isMotionDetectionEnabled,
    });

  }
}

Future<bool> clientSupportsH264() async {
  final pc = await createPeerConnection({}, {});
  try {
    final offer = await pc.createOffer({'offerToReceiveVideo': 1});
    final sdp = offer.sdp ?? '';
    final hasH264 = RegExp(
      r'a=rtpmap:\d+\s+H264\/',
      caseSensitive: false,
    ).hasMatch(sdp);
    debugPrint('Temporary offer SDP codecs -> H264=${hasH264}');
    await pc.close();
    return hasH264;
  } catch (e) {
    debugPrint('Error checking codecs: $e');
    await pc.close();
    return false;
  }
}
