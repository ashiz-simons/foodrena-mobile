import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/chat_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String orderId;
  final String callerName;
  final String senderRole;
  final String channelName;
  final String appId;
  final String? token;

  const IncomingCallScreen({
    super.key,
    required this.orderId,
    required this.callerName,
    required this.senderRole,
    required this.channelName,
    required this.appId,
    this.token,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _kGreen = Color(0xFF00D97E);
  static const _kRed   = Color(0xFFFF4757);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-decline after 30 seconds if no response
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) _decline();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _accept() {
    HapticFeedback.heavyImpact();
    // Notify caller that call was accepted
    ChatService.emitCallAccepted(widget.orderId, "");

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          orderId:       widget.orderId,
          senderRole:    widget.senderRole,
          recipientName: widget.callerName,
          isIncoming:    true,
          channelName:   widget.channelName,
          appId:         widget.appId,
          token:         widget.token,
        ),
      ),
    );
  }

  void _decline() {
    HapticFeedback.mediumImpact();
    ChatService.emitCallDeclined(widget.orderId);
    if (mounted) Navigator.pop(context);
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
              const Spacer(),

              // ── Incoming label ────────────────────────────────
              Text(
                "Incoming Call",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    letterSpacing: 1.2),
              ),

              const SizedBox(height: 32),

              // ── Pulsing avatar ────────────────────────────────
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGreen.withOpacity(0.15),
                      border: Border.all(
                          color: _kGreen.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.callerName.isNotEmpty
                            ? widget.callerName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                            color: _kGreen,
                            fontSize: 42,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Caller name ───────────────────────────────────
              Text(
                widget.callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 8),

              Text(
                "Foodrena order call",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13),
              ),

              const Spacer(),

              // ── Accept / Decline buttons ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    GestureDetector(
                      onTap: _decline,
                      child: Column(
                        children: [
                          Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kRed,
                              boxShadow: [
                                BoxShadow(
                                  color: _kRed.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 32),
                          ),
                          const SizedBox(height: 10),
                          Text("Decline",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13)),
                        ],
                      ),
                    ),

                    // Accept
                    GestureDetector(
                      onTap: _accept,
                      child: Column(
                        children: [
                          Container(
                            width: 70, height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: _kGreen.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.call_rounded,
                                color: Colors.white,
                                size: 32),
                          ),
                          const SizedBox(height: 10),
                          Text("Accept",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13)),
                        ],
                      ),
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
}