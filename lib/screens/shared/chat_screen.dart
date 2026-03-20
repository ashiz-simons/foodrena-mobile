import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../utils/session.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String senderRole;
  final String recipientName;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.senderRole,
    required this.recipientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _myUserId;

  static const _kTeal = Color(0xFF00B4B4);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await Session.getUserId();
    // Join the order socket room so we receive messages in real time
    await SocketService.connectToRoom("order_${widget.orderId}");
    await _loadMessages();
    _listenForMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await ChatService.getMessages(widget.orderId);
      if (mounted) {
        setState(() {
          _messages = res.map((m) => Map<String, dynamic>.from(m)).toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForMessages() {
    ChatService.onMessageReceived((msg) {
      if (!mounted) return;
      final msgOrderId = msg["orderId"]?.toString() ?? "";
      if (msgOrderId != widget.orderId) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    _input.clear();
    HapticFeedback.selectionClick();

    final optimistic = {
      "_id": DateTime.now().millisecondsSinceEpoch.toString(),
      "senderId": {"_id": _myUserId, "name": "You"},
      "senderRole": widget.senderRole,
      "text": text,
      "createdAt": DateTime.now().toIso8601String(),
      "read": false,
      "_optimistic": true,
    };

    setState(() {
      _messages.add(optimistic);
      _sending = true;
    });
    _scrollToBottom();

    try {
      await ChatService.sendMessage(
        orderId: widget.orderId,
        text: text,
        senderRole: widget.senderRole,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere(
            (m) => m["_id"] == optimistic["_id"]));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to send message"),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          orderId: widget.orderId,
          senderRole: widget.senderRole,
          recipientName: widget.recipientName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    ChatService.offMessageReceived();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _dark() => Theme.of(context).brightness == Brightness.dark;

  bool _isMe(Map msg) {
    final senderId = msg["senderId"];
    if (senderId is Map) {
      return senderId["_id"]?.toString() == _myUserId;
    }
    return senderId?.toString() == _myUserId;
  }

  String _formatTime(String? iso) {
    if (iso == null) return "";
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, "0");
      final m = dt.minute.toString().padLeft(2, "0");
      return "$h:$m";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _dark();
    final bg = dark ? const Color(0xFF081818) : const Color(0xFFF0FAFA);
    final card = dark ? const Color(0xFF0F2828) : Colors.white;
    final text = dark ? Colors.white : const Color(0xFF1A1A1A);
    final muted = dark ? Colors.grey.shade400 : const Color(0xFF6B8A8A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recipientName,
                style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text("Order chat",
                style: TextStyle(color: muted, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openCall,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_rounded,
                  color: _kTeal, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kTeal))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: muted.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text("No messages yet",
                                style: TextStyle(
                                    color: muted, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text("Send a message to get started",
                                style: TextStyle(
                                    color: muted.withOpacity(0.6),
                                    fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _messageBubble(_messages[i], card, text, muted),
                      ),
          ),

          // ── Input bar ─────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: BoxDecoration(
              color: card,
              border: Border(
                  top: BorderSide(
                      color: _kTeal.withOpacity(0.15), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: _kTeal.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _input,
                      style: TextStyle(color: text, fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle:
                            TextStyle(color: muted, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kTeal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _kTeal.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(
      Map msg, Color card, Color text, Color muted) {
    final isMe = _isMe(msg);
    final msgText = msg["text"] ?? "";
    final time = _formatTime(msg["createdAt"]);
    final senderName = isMe
        ? "You"
        : (msg["senderId"] is Map
            ? msg["senderId"]["name"] ?? ""
            : "");
    final role = msg["senderRole"] ?? "";
    final isOptimistic = msg["_optimistic"] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  senderName.isNotEmpty
                      ? senderName[0].toUpperCase()
                      : "?",
                  style: const TextStyle(
                      color: _kTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      "$senderName · $role",
                      style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? _kTeal : card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(_dark() ? 0.2 : 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msgText,
                    style: TextStyle(
                      color: isMe ? Colors.white : text,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time,
                          style: TextStyle(
                              color: muted, fontSize: 10)),
                      if (isMe && isOptimistic) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.access_time_rounded,
                            size: 10, color: muted),
                      ] else if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.done_all_rounded,
                            size: 11, color: muted),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}