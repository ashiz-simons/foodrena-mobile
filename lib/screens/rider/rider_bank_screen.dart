import 'package:flutter/material.dart';
import '../../services/rider_bank_service.dart';

class RiderBankScreen extends StatefulWidget {
  const RiderBankScreen({super.key});

  @override
  State<RiderBankScreen> createState() => _RiderBankScreenState();
}

class _RiderBankScreenState extends State<RiderBankScreen> {
  final _formKey = GlobalKey<FormState>();

  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _bankName = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  Future<void> _loadBank() async {
    try {
      final bank = await RiderBankService.getMyBank();
      if (bank != null) {
        _accountName.text = bank["accountName"] ?? "";
        _accountNumber.text = bank["accountNumber"] ?? "";
        _bankName.text = bank["bankName"] ?? "";
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      await RiderBankService.saveBank(
        accountName: _accountName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        bankName: _bankName.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bank details saved")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save bank details")),
      );
    }

    setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bank Details")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _accountName,
                      decoration:
                          const InputDecoration(labelText: "Account Name"),
                      validator: (v) =>
                          v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountNumber,
                      decoration:
                          const InputDecoration(labelText: "Account Number"),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bankName,
                      decoration:
                          const InputDecoration(labelText: "Bank Name"),
                      validator: (v) =>
                          v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving ? null : _save,
                        child: saving
                            ? const CircularProgressIndicator()
                            : const Text("Save Bank Details"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
