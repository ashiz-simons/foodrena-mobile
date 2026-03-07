import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class VendorOnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const VendorOnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<VendorOnboardingScreen> createState() =>
      _VendorOnboardingScreenState();
}

class _VendorOnboardingScreenState extends State<VendorOnboardingScreen> {
  final businessCtrl = TextEditingController();
  final streetCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final accountNumberCtrl = TextEditingController();
  final accountNameCtrl = TextEditingController();

  String selectedZone = "zone_a";
  bool loading = false;
  String error = "";

  @override
  void dispose() {
    businessCtrl.dispose();
    streetCtrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    countryCtrl.dispose();
    bankNameCtrl.dispose();
    accountNumberCtrl.dispose();
    accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (businessCtrl.text.trim().isEmpty ||
        streetCtrl.text.trim().isEmpty ||
        cityCtrl.text.trim().isEmpty ||
        bankNameCtrl.text.trim().isEmpty ||
        accountNumberCtrl.text.trim().isEmpty) {
      setState(() => error = "Please fill in all required fields");
      return;
    }

    setState(() { loading = true; error = ""; });

    try {
      final res = await ApiService.post("/vendors/onboard", {
        "businessName": businessCtrl.text.trim(),
        "street": streetCtrl.text.trim(),
        "city": cityCtrl.text.trim(),
        "state": stateCtrl.text.trim(),
        "country": countryCtrl.text.trim(),
        "bankName": bankNameCtrl.text.trim(),
        "accountNumber": accountNumberCtrl.text.trim(),
        "accountName": accountNameCtrl.text.trim(),
        "zone": selectedZone,
      });

      if (!mounted) return;
      setState(() => loading = false);

      if (res["vendor"] != null || res["message"] == "Onboarding completed") {
        widget.onCompleted();
      } else {
        setState(() => error = res["message"] ?? "Failed");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? inputType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.green, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Onboarding"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        // ✅ Back button works normally
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Business Info", Icons.storefront_outlined),
            _field("Business Name", businessCtrl),

            _sectionHeader("Address", Icons.location_on_outlined),
            _field("Street", streetCtrl),
            _field("City", cityCtrl),
            _field("State", stateCtrl),
            _field("Country", countryCtrl),

            _sectionHeader("Delivery Zone", Icons.map_outlined),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: selectedZone,
                decoration: InputDecoration(
                  labelText: "Zone",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "zone_a", child: Text("Zone A")),
                  DropdownMenuItem(value: "zone_b", child: Text("Zone B")),
                  DropdownMenuItem(value: "zone_c", child: Text("Zone C")),
                ],
                onChanged: (val) => setState(() => selectedZone = val!),
              ),
            ),

            _sectionHeader("Bank Details", Icons.account_balance_outlined),
            _field("Bank Name", bankNameCtrl),
            _field("Account Number", accountNumberCtrl,
                inputType: TextInputType.number),
            _field("Account Name", accountNameCtrl),

            if (error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: loading ? null : submit,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text("Complete Onboarding",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}