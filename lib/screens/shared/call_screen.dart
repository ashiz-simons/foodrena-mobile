import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/chat_service.dart';

class CallScreen extends StatefulWidget {
  final String orderId;
  final String senderRole;
  final String recipientName;
  final bool isIncoming;
  final String? channelName;
  final String? appId;
  final String? token;

  const CallScreen({
    super.key,
    required this.orderId,
    required this.senderRole,
    required this.recipientName,
    this.isIncoming = false,
    this.channelName,
    this.appId,
    this.token,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  bool _joined        = false;
  bool _muted         = false;
  bool _speakerOn     = false;
  bool _connecting    = true;
  bool _callEnded     = false;
  bool _waitingAccept = false; // caller waiting for recipient
  int  _timerSeconds  = 0;
  bool _timerRunning  = false;

  late String _channelName;
  late String _appId;
  String? _token;

  static const _kGreen = Color(0xFF00D97E);
  static const _kRed   = Color(0xFFFF4757);
  static const _realAppId = "e03b6ecb7bcf4e279d314411ec817e7e";

  @override
  void initState() {
    super.initState();
    _channelName    = widget.channelName ?? widget.orderId;
    _appId          = widget.appId ?? _realAppId;
    _token          = widget.token;
    _listenForCallEvents();

    if (widget.isIncoming) {
      // Incoming — join immediately, token already passed in
      _initAgora(token: _token, channelName: _channelName, appId: _appId);
    } else {
      // Outgoing — generate token first, then wait for accept
      setState(() => _waitingAccept = true);
      _initiateOutgoingCall();
    }
  }

  Future<void> _initiateOutgoingCall() async {
    try {
      // This triggers call_invite on the backend to the recipient
      final res = await ChatService.generateCallToken(orderId: widget.orderId);
      _token       = res["token"];
      _channelName = res["channelName"] ?? _channelName;
      _appId       = res["appId"] ?? _appId;
      // Wait for call_accepted before joining
    } catch (e) {
      debugPrint("Call initiate error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to start call: $e"),
              backgroundColor: _kRed));
        Navigator.pop(context);
      }
    }
  }

 Future<void> _initAgora({
    required String? token,
    required String channelName,
    required String appId,
  }) async {
    try {
      // Request mic permission BEFORE initializing Agora
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Microphone permission required for calls"),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      setState(() { _waitingAccept = false; _connecting = true; });

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));
      await _engine!.enableAudio();
      await _engine!.setChannelProfile(
          ChannelProfileType.channelProfileCommunication);
      await _engine!.setClientRole(
          role: ClientRoleType.clientRoleBroadcaster);

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) setState(() { _joined = true; _connecting = false; });
          _startTimer();
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) _endCall(notify: false);
        },
        onError: (err, msg) {
          debugPrint("Agora error: $err — $msg");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Call error: $msg"),
                  backgroundColor: _kRed));
          }
        },
      ));

      await _engine!.joinChannel(
        token: token ?? "",
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Agora init error: $e");
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _listenForCallEvents() {
    // Recipient accepted — caller can now join
    ChatService.onCallAccepted((_) {
      if (!mounted) return;
      if (!widget.isIncoming && _waitingAccept) {
        _initAgora(
          token: _token,
          channelName: _channelName,
          appId: _appId,
        );
      }
    });

    ChatService.onCallEnded((_) {
      if (mounted) _endCall(notify: false);
    });

    ChatService.onCallDeclined((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Call declined"),
              backgroundColor: _kRed),
        );
        _endCall(notify: false);
      }
    });
  }

  void _startTimer() {
    _timerRunning = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_timerRunning) return false;
      setState(() => _timerSeconds++);
      return true;
    });
  }

  String get _durationLabel {
    final m = (_timerSeconds ~/ 60).toString().padLeft(2, "0");
    final s = (_timerSeconds % 60).toString().padLeft(2, "0");
    return "$m:$s";
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await _engine?.setEnableSpeakerphone(_speakerOn);
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  Future<void> _endCall({bool notify = true}) async {
    _timerRunning = false;
    if (notify) ChatService.emitCallEnded(widget.orderId);
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) {
      setState(() => _callEnded = true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timerRunning = false;
    ChatService.offAllCallEvents();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Avatar ───────────────────────────────────────
              Center(
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreen.withOpacity(0.15),
                    border: Border.all(
                        color: _kGreen.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      widget.recipientName.isNotEmpty
                          ? widget.recipientName[0].toUpperCase()
                          : "?",
                      style: const TextStyle(
                          color: _kGreen,
                          fontSize: 36,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(widget.recipientName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ),

              const SizedBox(height: 8),

              // ── Status ───────────────────────────────────────
              Center(
                child: Text(
                  _callEnded
                      ? "Call ended"
                      : _waitingAccept
                          ? "Ringing..."
                          : _connecting
                              ? "Connecting..."
                              : _joined
                                  ? _durationLabel
                                  : "Waiting...",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15),
                ),
              ),

              if (_waitingAccept) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Waiting for ${widget.recipientName} to answer",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12),
                  ),
                ),
              ],

              const Spacer(),

              // ── Controls ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                child: _waitingAccept
                    ? // Only show end button while ringing
                    _controlButton(
                        icon: Icons.call_end_rounded,
                        label: "Cancel",
                        color: Colors.white,
                        bgColor: _kRed,
                        size: 64,
                        onTap: () => _endCall(),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _controlButton(
                            icon: _muted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            label: _muted ? "Unmute" : "Mute",
                            color: _muted
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            bgColor: _muted
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.08),
                            onTap: _toggleMute,
                          ),
                          _controlButton(
                            icon: Icons.call_end_rounded,
                            label: "End",
                            color: Colors.white,
                            bgColor: _kRed,
                            size: 64,
                            onTap: () => _endCall(),
                          ),
                          _controlButton(
                            icon: _speakerOn
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            label: _speakerOn ? "Speaker" : "Earpiece",
                            color: _speakerOn
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            bgColor: _speakerOn
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.08),
                            onTap: _toggleSpeaker,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Icon(icon, color: color, size: size * 0.4),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11)),
        ],
      ),
    );
  }
}