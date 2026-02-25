import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'order_status_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String authorizationUrl;
  final String orderId;

  const PaymentScreen({
    super.key,
    required this.authorizationUrl,
    required this.orderId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _showContinue = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.authorizationUrl));

    // ⏱ MVP fallback: show continue button after delay
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _showContinue = true);
      }
    });
  }

  void _continueToOrderStatus() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderStatusScreen(orderId: widget.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Payment")),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_showContinue)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _continueToOrderStatus,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "I’ve completed payment",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}