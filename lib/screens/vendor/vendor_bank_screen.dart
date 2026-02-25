import 'package:flutter/material.dart';
import '../../services/vendor_service.dart';

class VendorBankScreen extends StatefulWidget {
  const VendorBankScreen({super.key});

  @override
  State<VendorBankScreen> createState() => _VendorBankScreenState();
}

class _VendorBankScreenState extends State<VendorBankScreen> {
  final bankName = TextEditingController();
  final accountNumber = TextEditingController();
  final accountName = TextEditingController();

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadBank();
  }

  Future<void> loadBank() async {
    final data = await VendorService.getBank();

    bankName.text = data["bankName"] ?? "";
    accountNumber.text = data["accountNumber"] ?? "";
    accountName.text = data["accountName"] ?? "";

    setState(() => loading = false);
  }

  Future<void> save() async {
    await VendorService.saveBank({
      "bankName": bankName.text,
      "accountNumber": accountNumber.text,
      "accountName": accountName.text,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bank details saved")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bank Details")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: bankName,
                    decoration: const InputDecoration(labelText: "Bank Name"),
                  ),
                  TextField(
                    controller: accountNumber,
                    decoration:
                        const InputDecoration(labelText: "Account Number"),
                  ),
                  TextField(
                    controller: accountName,
                    decoration:
                        const InputDecoration(labelText: "Account Name"),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: save,
                    child: const Text("Save"),
                  )
                ],
              ),
            ),
    );
  }
}
