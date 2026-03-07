import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_service.dart';
import 'order_status_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String authorizationUrl;
  final String orderId;
  final String reference;

  const PaymentScreen({
    super.key,
    required this.authorizationUrl,
    required this.orderId,
    required this.reference,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  bool _verifying = false;
  bool _navigated = false;
  bool _showManualButton = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            final status = uri.queryParameters["status"];

            if (status == "success" ||
                uri.path.contains("payment/success") ||
                uri.path.contains("callback")) {
              // ✅ Delay so we're outside the WebView navigation callback
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _verifyAndContinue();
              });
              return NavigationDecision.prevent;
            }

            if (status == "cancelled" || status == "failed") {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showError("Payment was cancelled or failed.");
              });
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_navigated) {
        setState(() => _showManualButton = true);
      }
    });
  }

  Future<void> _verifyAndContinue() async {
    if (_navigated || _verifying) return;
    if (!mounted) return;

    setState(() {
      _verifying = true;
      _showManualButton = false;
    });

    try {
      final res = await ApiService.get("/payments/verify/${widget.reference}");

      if (!mounted) return;

      if (res == null || res["status"] != "paid") {
        setState(() {
          _verifying = false;
          _showManualButton = true;
        });
        _showError("Payment not confirmed yet. Please complete payment first.");
        return;
      }

      // ✅ Mark navigated before any async gap
      _navigated = true;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusScreen(orderId: widget.orderId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll("Exception: ", "");
      final friendly = msg.contains("Payment not completed")
          ? "Payment not completed yet. Please finish paying first."
          : msg;
      setState(() {
        _verifying = false;
        _showManualButton = true;
      });
      _showError(friendly);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<bool> _handleBack() async {
    if (_verifying) return false;
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        appBar: AppBar(title: const Text("Complete Payment")),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),

            if (_verifying)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        "Verifying payment...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

            if (_showManualButton && !_verifying)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: ElevatedButton(
                  onPressed: _verifyAndContinue,
                  child: const Text("I've completed payment — verify now"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
