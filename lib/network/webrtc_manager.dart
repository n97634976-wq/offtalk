import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'packet_router.dart';

class WebRTCManager {
  static final WebRTCManager instance = WebRTCManager._init();
  WebRTCManager._init();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? remoteStream;

  Function(MediaStream stream)? onAddRemoteStream;
  Function(MediaStream stream)? onRemoveRemoteStream;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      // Only useful if bridging on libp2p, otherwise mesh relies on local direct IPs
      {'url': 'stun:stun.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  /// Initialize local media (camera/mic)
  Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });
    
    localVideo.srcObject = stream;
    _localStream = stream;
    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  /// Start a call by generating an offer and routing it over the mesh
  Future<void> makeCall(String targetId) async {
    _peerConnection = await createPeerConnection(_configuration);
    
    _peerConnection!.onAddStream = (stream) {
      remoteStream = stream;
      if (onAddRemoteStream != null) onAddRemoteStream!(stream);
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      // Send candidate via PacketRouter
      final payload = jsonEncode({
        'type': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      // PacketRouter.instance.routeMessage(targetId, utf8.encode(payload));
    };

    RTCSessionDescription offer = await _peerConnection!.createOffer(_offerSdpConstraints);
    await _peerConnection!.setLocalDescription(offer);

    // Send the offer via PacketRouter
    final payload = jsonEncode({
      'type': 'offer',
      'sdp': offer.sdp,
    });
    // PacketRouter.instance.routeMessage(targetId, utf8.encode(payload));
  }

  // Incoming signaling handlers
  Future<void> handleSignalMessage(String senderId, Map<String, dynamic> data) async {
    if (data['type'] == 'offer') {
      _peerConnection = await createPeerConnection(_configuration);

      _peerConnection!.onAddStream = (stream) {
        remoteStream = stream;
        if (onAddRemoteStream != null) onAddRemoteStream!(stream);
      };

      _localStream?.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (candidate) {
        // ... send candidate
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type'])
      );
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer
      /*
      final payload = jsonEncode({'type': 'answer', 'sdp': answer.sdp});
      PacketRouter.instance.routeMessage(senderId, utf8.encode(payload));
      */
    } else if (data['type'] == 'answer') {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type'])
      );
    } else if (data['type'] == 'ice') {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex'])
      );
    }
  }

  Future<void> hangUp() async {
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        await _localStream!.dispose();
        _localStream = null;
      }
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
    } catch (e) {
      print(e.toString());
    }
  }
}
