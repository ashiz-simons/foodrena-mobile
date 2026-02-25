import 'package:flutter/material.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  String status = 'processing';

  @override
  void initState() {
    super.initState();

    // MVP: Fake progression (backend will handle real updates later)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => status = 'searching_rider');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Status')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statusWidget(),
            const SizedBox(height: 24),
            Text(
              'Order ID: ${widget.orderId}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusWidget() {
    switch (status) {
      case 'searching_rider':
        return _row('Searching for rider', Icons.search);
      case 'picked_up':
        return _row('Order picked up', Icons.delivery_dining);
      case 'delivered':
        return _row('Delivered 🎉', Icons.done_all);
      default:
        return _row('Processing payment', Icons.hourglass_bottom);
    }
  }

  Widget _row(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 20)),
      ],
    );
  }
}