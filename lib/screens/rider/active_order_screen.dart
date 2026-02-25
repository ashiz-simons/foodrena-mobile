import 'package:flutter/material.dart';
import '../../services/rider_service.dart';

class ActiveOrderScreen extends StatefulWidget {
  final Map order;

  const ActiveOrderScreen({super.key, required this.order});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  late Map order;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    order = widget.order;
  }

  Future<void> updateStatus(String action) async {
    setState(() => loading = true);

    try {
      if (action == "arrived") {
        await RiderService.arrived(order["_id"]);
        order["status"] = "arrived";
      }

      if (action == "start-trip") {
        await RiderService.startTrip(order["_id"]);
        order["status"] = "in_transit";
      }

      if (action == "complete") {
        await RiderService.complete(order["_id"]);
        order["status"] = "completed";
      }

      setState(() {});
    } catch (_) {}

    setState(() => loading = false);
  }

  Widget buildActionButton() {
    switch (order["status"]) {
      case "accepted":
        return buildButton("Mark Arrived", "arrived");

      case "arrived":
        return buildButton("Start Trip", "start-trip");

      case "in_transit":
        return buildButton("Complete Delivery", "complete");

      case "completed":
        return const Text(
          "Delivery Completed",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        );

      default:
        return const SizedBox();
    }
  }

  Widget buildButton(String text, String action) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : () => updateStatus(action),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Delivery")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order ID: ${order["_id"]}",
                style: const TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            Text("Customer: ${order["customerName"] ?? "Unknown"}"),
            Text("Delivery Address: ${order["deliveryAddress"] ?? "N/A"}"),
            Text("Total: ₦${order["total"]}"),
            Text("Status: ${order["status"]}"),

            const Spacer(),

            buildActionButton(),
          ],
        ),
      ),
    );
  }
}
