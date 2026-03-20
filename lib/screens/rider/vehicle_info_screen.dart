import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';

class VehicleInfoScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const VehicleInfoScreen({super.key, required this.onCompleted});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final plateCtrl = TextEditingController();
  String selectedVehicle = "bike";
  bool loading = false;
  String error = "";

  final vehicles = ["bike", "car", "truck"];

  @override
  void dispose() {
    plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (plateCtrl.text.trim().isEmpty) {
      setState(() => error = "Please enter your vehicle plate number");
      return;
    }

    setState(() { loading = true; error = ""; });

    try {
      await ApiService.patch("/riders/vehicle", {
        "vehicleType":  selectedVehicle,
        "vehiclePlate": plateCtrl.text.trim(),
      });

      if (!mounted) return;

      // Switch role to rider so the token/session is fresh before routing
      try {
        final res = await ApiService.post("/auth/switch-role", {"role": "rider"});
        await Session.saveToken(res["token"]);
        await Session.saveUser(res["user"]);
      } catch (_) {
        // If already rider, switch-role may 400 — that's fine, continue
      }

      if (!mounted) return;

      // Pop this screen first, THEN call onCompleted so RoleRouter
      // rebuilds underneath a clean stack
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceAll("Exception: ", "");
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vehicle Info")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "To become a rider, we need your vehicle details.",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            const Text("Vehicle Type",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            Row(
              children: vehicles.map((v) {
                final selected = v == selectedVehicle;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedVehicle = v),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          v[0].toUpperCase() + v.substring(1),
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            const Text("Plate Number",
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            TextField(
              controller: plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: "e.g. ABC-123-XY",
                border: OutlineInputBorder(),
              ),
            ),

            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error,
                    style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _save,
                child: loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Save & Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}