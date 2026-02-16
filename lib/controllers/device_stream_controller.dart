import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/foundation.dart';
import '/models/device.dart';
import '/services/firebase_service.dart';
import '/services/janus_service.dart';
import '/services/fb_service.dart'; // Import FBService

/// Controller responsible for managing the device state and the WebRTC video stream.
class DeviceStreamController extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final FBService _fbService; // Added FBService
  final JanusService _janusService;
  final String _deviceId;
  final String? _serverId; // Added serverId

  // Track disposal to prevent async race conditions
  bool _isDisposed = false;
  
  // Track renderer initialization state
  bool _isRendererInitialized = false;

  StreamSubscription? _janusResponseSubscription;

  // --- Device State ---
  Device? _device;
  String? _errorMessage;
  bool _isToggling = false;

  Device? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get isToggling => _isToggling;

  // --- WebRTC State ---
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _remoteStream;

  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get hasActiveStream => _remoteRenderer.srcObject != null;

  // --- WebRTC Configuration ---
  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': 'stun:stun.l.google.com:19302',
      },
      {
        'urls': 'turn:192.168.1.11:3478',
        'username': 'janus',
        'credential': 'janus',
      },
    ],
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
  };

  // Constructor
  DeviceStreamController(
    this._firebaseService,
    this._fbService,
    this._janusService,
    this._deviceId, {
    String? serverId,
  }) : _serverId = serverId {
    _initializeSequence();
  }

  Future<void> _initializeSequence() async {
    await _initRenderers();
    // Start WebRTC session setup via Janus after renderers are ready
    if (!_isDisposed) {
      _startWebRTCSession();
    }
  }

  // --- Initialization & Disposal ---

  Future<void> _initRenderers() async {
    try {
      await _remoteRenderer.initialize();
      _isRendererInitialized = true;
    } catch (e) {
      debugPrint('Error initializing renderer: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanupWebRTC();
    _janusService.disconnect().catchError((e) {
      debugPrint('Error disconnecting JanusService: $e');
    });
    if (_isRendererInitialized) {
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  Future<void> _cleanupWebRTC() async {
    // Cancel any Janus response subscription
    await _janusResponseSubscription?.cancel();
    _janusResponseSubscription = null;

    // Close and null out the peer connection
    await _peerConnection?.close();
    _peerConnection = null;

    // Clear renderer / local stream
    _remoteStream = null;
    
    // Only clear srcObject if initialized to avoid "Call initialize before setting the stream"
    if (_isRendererInitialized) {
      try {
        _remoteRenderer.srcObject = null;
      } catch (e) {
        debugPrint('Ignored error clearing srcObject: $e');
      }
    }
  }

  /// Connects to the Janus stream and (re)starts the WebRTC session.
  Future<void> connectToStream() async {
    if (_isDisposed) return;
    try {
      if (!_isRendererInitialized) {
        await _initRenderers();
      }
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
    await _cleanupWebRTC();

    // Request Janus to detach/destroy the session
    try {
      await _janusService.disconnect();
    } catch (e) {
      debugPrint('JanusService.disconnect error: $e');
    }

    if (!_isDisposed) {
      notifyListeners();
    }
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
    if (_isDisposed) return;

    // Ensure clean state before starting
    await _cleanupWebRTC();

    // 1. Get Janus Token from FBService if serverId is available
    String? janusToken;
    if (_serverId != null) {
      try {
        debugPrint('Fetching Janus token for server: $_serverId');
        janusToken = await _fbService.getToken(_serverId);
        debugPrint('Token received from FBService: $janusToken');
        if (janusToken != null) {
          _janusService.setToken(janusToken);
          debugPrint('Janus token set successfully: $janusToken');
        } else {
          debugPrint('Warning: Received null token from FBService.');
          _errorMessage = 'Failed to get authentication token for Janus server';
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Error fetching Janus token: $e');
        _errorMessage = 'Error fetching authentication token: $e';
        notifyListeners();
        return;
      }
    } else {
      debugPrint('Error: serverId is null, cannot retrieve token.');
      _errorMessage = 'Server ID is missing, cannot connect to stream';
      notifyListeners();
      return;
    }

    // 2. Connect to Janus Gateway and establish session
    try {
      await _janusService.connect();
    } catch (e) {
      if (_isDisposed) return;
      _errorMessage = "Failed to connect to Janus Gateway: $e";
      notifyListeners();
      return;
    }

    if (_isDisposed) return;

    // 3. Create the Peer Connection
    try {
      _peerConnection = await createPeerConnection(_iceServers, {});
    } catch (e) {
      debugPrint('Failed to create PeerConnection: $e');
      return;
    }
    
    if (_isDisposed) {
      await _peerConnection?.close();
      _peerConnection = null;
      return;
    }

    debugPrint('PeerConnection created.');

    // Log connection / signaling state
    _peerConnection?.onIceConnectionState = (state) {
      debugPrint('🔌 PeerConnection ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('⚠️ ICE connection problems detected!');
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        debugPrint('✓ ICE connection established successfully');
      }
    };
    _peerConnection?.onConnectionState = (state) {
      debugPrint('🔌 PeerConnection connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('✓ Peer connection fully established');
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        debugPrint('❌ Peer connection FAILED');
        _errorMessage = 'Connection failed - please check network';
        if (!_isDisposed) notifyListeners();
      }
    };
    _peerConnection?.onSignalingState = (state) {
      debugPrint('📡 PeerConnection signaling state: $state');
    };
    _peerConnection?.onIceGatheringState = (state) {
      debugPrint('🧊 PeerConnection ICE gathering state: $state');
    };

    // 4. Setup remote track listener
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint('🎬 onTrack event fired!');
      debugPrint('Track kind: ${event.track.kind}');
      debugPrint('Track enabled: ${event.track.enabled}');
      debugPrint('Track id: ${event.track.id}');
      debugPrint('Number of streams: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        debugPrint('Stream id: ${event.streams[0].id}');
        debugPrint('Stream tracks: ${event.streams[0].getTracks().length}');
      }

      if (event.streams.isNotEmpty && event.track.kind == 'video') {
        if (_isRendererInitialized) {
           _remoteRenderer.srcObject = event.streams[0];
           _remoteStream = event.streams[0];
           debugPrint('✅ Remote video stream attached to renderer!');
           debugPrint('Stream ID: ${event.streams[0].id}');

           // Notify UI that stream is ready
           if (!_isDisposed) notifyListeners();
        } else {
           debugPrint('⚠️ Warning: Received track but renderer not initialized.');
        }
      } else if (event.track.kind == 'audio') {
        debugPrint('🔊 Audio track received (not displayed)');
      } else {
        debugPrint('⚠️ Received track but no streams or not video type');
      }
    };

    // 5. Setup local ICE candidate sender
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        debugPrint('🧊 Local ICE candidate generated: ${candidate.candidate?.substring(0, 50)}...');
        _janusService.sendTrickleCandidate(candidate).catchError((e) {
          debugPrint('❌ Error sending trickle candidate to Janus: $e');
        });
      } else {
        debugPrint(
          'Local ICE gathering completed (null candidate). Sending completed trickle.',
        );
        _janusService.sendTrickleCandidate(null);
      }
    };

    // 6. Listen to Janus messages for the SDP Offer and Candidates
    _janusResponseSubscription = _janusService.janusResponses.listen(
      (json) async {
        if (_isDisposed) return;

        debugPrint('=== JANUS MESSAGE RECEIVED ===');
        debugPrint('Full message: $json');

        final senderHandle = json['sender']?.toString();
        final janusType = json['janus'] as String?;
        final plugindata = json['plugindata'] as Map<String, dynamic>?;
        final jsep = json['jsep'] as Map<String, dynamic>?;

        debugPrint('Sender handle: $senderHandle');
        debugPrint('Publisher handle: ${_janusService.publisherHandleId}');
        debugPrint('Subscriber handle: ${_janusService.subscriberHandleId}');
        debugPrint('Message type: $janusType');

        // --- A. Publisher Events (on _publisherHandleId) ---
        if (senderHandle == _janusService.publisherHandleId && plugindata != null) {
           debugPrint('--- PUBLISHER EVENT ---');
           final data = plugindata['data'] as Map<String, dynamic>;
           final event = data['videoroom'];
           debugPrint('VideoRoom event: $event');
           debugPrint('Full data: $data');

           if (event == 'joined') {
              debugPrint('✓ Joined room as publisher (viewer mode).');
              debugPrint('Publishers in room: ${data['publishers']}');
              if (data['publishers'] != null) {
                 final publishers = data['publishers'] as List;
                 debugPrint('Number of publishers: ${publishers.length}');
                 if (publishers.isEmpty) {
                    debugPrint('⚠️ NO PUBLISHERS AVAILABLE IN ROOM!');
                    _errorMessage = 'No active camera stream found in room';
                    if (!_isDisposed) notifyListeners();
                 } else {
                    // Subscribe to the first available publisher
                    final feedId = publishers[0]['id'];
                    final display = publishers[0]['display'];
                    debugPrint('→ Subscribing to feed: $feedId (display: $display)');
                    await _janusService.subscribeToFeed(feedId);
                 }
              } else {
                 debugPrint('⚠️ Publishers field is NULL!');
              }
           } else if (event == 'event') {
              debugPrint('--- PUBLISHER EVENT (new publisher) ---');
              if (data['publishers'] != null) {
                  final publishers = data['publishers'] as List;
                  debugPrint('New publishers count: ${publishers.length}');
                  if (publishers.isNotEmpty) {
                      final feedId = publishers[0]['id'];
                      debugPrint('→ New publisher available: $feedId, subscribing...');
                      await _janusService.subscribeToFeed(feedId);
                  }
              }
           }
        }

        // --- B. Subscriber Events (on _subscriberHandleId) ---
        if (senderHandle == _janusService.subscriberHandleId) {
            debugPrint('--- SUBSCRIBER EVENT ---');

            // Log plugindata if present
            if (plugindata != null) {
               debugPrint('Subscriber plugindata: $plugindata');
            }

            // 1. Handle JSEP (SDP Offer) from Janus
            if (jsep != null) {
              debugPrint('→ JSEP received from subscriber handle');
              final type = jsep['type'] as String?;
              final sdp = jsep['sdp'] as String?;
              debugPrint('JSEP type: $type');
              debugPrint('SDP present: ${sdp != null}');

              if (type == 'offer' && sdp != null) {
                if (_peerConnection == null) {
                   debugPrint('❌ PeerConnection is null when receiving offer. Skipping.');
                   return;
                }
                
                try {
                  debugPrint('✓ Received SDP Offer from Janus Subscriber Handle.');
                  debugPrint('SDP Offer (first 500 chars): ${sdp.substring(0, sdp.length > 500 ? 500 : sdp.length)}');

                  // Add transceivers for receiving media (recvonly direction)
                  try {
                    debugPrint('Adding transceiver for video (recvonly)...');
                    await _peerConnection!.addTransceiver(
                      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
                      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
                    );
                    debugPrint('✓ Video transceiver added');
                  } catch (e) {
                    debugPrint('Note: Could not add video transceiver (may already exist): $e');
                  }

                  try {
                    debugPrint('Adding transceiver for audio (recvonly)...');
                    await _peerConnection!.addTransceiver(
                      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
                      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
                    );
                    debugPrint('✓ Audio transceiver added');
                  } catch (e) {
                    debugPrint('Note: Could not add audio transceiver (may already exist): $e');
                  }

                  await _peerConnection!.setRemoteDescription(
                    RTCSessionDescription(sdp, type),
                  );
                  debugPrint('✓ Remote description set successfully');

                  if (_isDisposed || _peerConnection == null) return;

                  final answer = await _peerConnection!.createAnswer({
                    'mandatory': {
                      'OfferToReceiveAudio': true,
                      'OfferToReceiveVideo': true,
                    }
                  });
                  debugPrint('✓ Local SDP Answer created.');
                  debugPrint('Answer SDP (first 800 chars): ${answer.sdp!.substring(0, answer.sdp!.length > 800 ? 800 : answer.sdp!.length)}');

                  final updatedSdp = _preferCodec(answer.sdp!, 'H264');
                  final updatedAnswer = RTCSessionDescription(updatedSdp, answer.type);

                  debugPrint('Updated Answer SDP (first 800 chars): ${updatedSdp.substring(0, updatedSdp.length > 800 ? 800 : updatedSdp.length)}');

                  if (_isDisposed || _peerConnection == null) return;
                  await _peerConnection!.setLocalDescription(updatedAnswer);
                  debugPrint('✓ Local description set successfully');

                  await _janusService.sendAnswer(updatedAnswer);
                  debugPrint('✓ SDP Answer sent to Janus with forced H264 preference.');
                } catch (e, st) {
                  debugPrint('❌ Error handling SDP offer/answer flow: $e\n$st');
                  _errorMessage = 'WebRTC SDP handling error: $e';
                  if (!_isDisposed) notifyListeners();
                }
              }
            } else {
              debugPrint('No JSEP in subscriber message');
            }
        }

        // --- C. Trickle Candidates ---
        final candidateJson = json['candidate'] as Map<String, dynamic>?;
        if (janusType == 'trickle' && candidateJson != null) {
          debugPrint('→ ICE Trickle candidate received');

          if (candidateJson['completed'] == true) {
             debugPrint('✓ Janus ICE gathering complete.');
             return;
          }

          debugPrint('Candidate details: ${candidateJson['candidate']}');

          if (_peerConnection == null) {
             debugPrint('❌ PeerConnection is null, cannot add ICE candidate');
             return;
          }

          try {
            final cand = RTCIceCandidate(
              candidateJson['candidate'] as String?,
              candidateJson['sdpMid'] as String?,
              candidateJson['sdpMLineIndex'] as int?,
            );
            await _peerConnection?.addCandidate(cand);
            debugPrint('✓ ICE candidate added to peer connection');
          } catch (e) {
            debugPrint('❌ Error adding remote ICE candidate: $e');
          }
        }

        // --- D. Handle webrtcup event ---
        if (janusType == 'webrtcup') {
           debugPrint('🎉 WebRTC PeerConnection is UP! Stream should be flowing now.');
        }

        // --- E. Handle media event ---
        if (janusType == 'media') {
           debugPrint('📺 Media event: type=${json['type']}, receiving=${json['receiving']}');
        }

        // --- F. Handle hangup ---
        if (janusType == 'hangup') {
           debugPrint('📞 Hangup received: ${json['reason']}');
           _errorMessage = 'Stream ended: ${json['reason']}';
           if (!_isDisposed) notifyListeners();
        }

        // --- G. Handle errors ---
        if (janusType == 'error') {
           debugPrint('❌ Janus Error: ${json['error']}');
           _errorMessage = 'Janus error: ${json['error']?['reason'] ?? 'Unknown error'}';
           if (!_isDisposed) notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = "Janus signaling error: $error";
        if (!_isDisposed) notifyListeners();
      },
    );

    // 7. Attach Main Publisher Handle & Join Room
    await _janusService.attachAsPublisher();
    await _janusService.joinRoomAsPublisher(); 
  }

  // --- Control Methods ---

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
    await _updateState({
      'isMotionDetectionEnabled': !_device!.isMotionDetectionEnabled,
    });
  }

  // Helper to modify SDP to prefer a specific codec
  String _preferCodec(String sdp, String codec) {
    final sdpLines = sdp.split('\r\n');
    final mVideoIndex = sdpLines.indexWhere((line) => line.startsWith('m=video'));
    if (mVideoIndex == -1) return sdp;

    final mVideoLine = sdpLines[mVideoIndex];
    final parts = mVideoLine.split(' ');
    if (parts.length < 4) return sdp;

    final payloadTypes = parts.sublist(3); 

    String? preferredPt;
    for (final line in sdpLines) {
      if (line.startsWith('a=rtpmap:') && line.toUpperCase().contains(codec.toUpperCase())) {
        final pt = line.split(':')[1].split(' ')[0];
        preferredPt = pt;
        break; 
      }
    }

    if (preferredPt == null) {
       debugPrint('Codec $codec not found in SDP, cannot prefer it.');
       return sdp;
    }

    if (payloadTypes.contains(preferredPt)) {
      payloadTypes.remove(preferredPt);
      payloadTypes.insert(0, preferredPt);
      
      final newMLine = '${parts[0]} ${parts[1]} ${parts[2]} ${payloadTypes.join(' ')}';
      sdpLines[mVideoIndex] = newMLine;
      debugPrint('Reordered SDP to prefer codec $codec (PT $preferredPt)');
      return sdpLines.join('\r\n');
    }

    return sdp;
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
