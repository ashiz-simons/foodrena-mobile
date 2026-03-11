import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../rider/vehicle_info_screen.dart';
import '../vendor/vendor_onboarding_screen.dart';
import 'phone_auth_screen.dart';

// 🔧 Feature flag — set to true when Firebase billing is enabled
const bool PHONE_VERIFY_ENABLED = false;

class RegisterScreen extends StatefulWidget {
  final String role;
  final VoidCallback? onRegister;

  const RegisterScreen({super.key, required this.role, this.onRegister});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _registered = false;
  bool _phoneVerified = false;
  String? _verifiedIdToken;
  String error = "";

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => error = "Enter your phone number first");
      return;
    }

    // 🔧 OTP disabled — auto-verify until Firebase billing is enabled
    if (!PHONE_VERIFY_ENABLED) {
      setState(() {
        _phoneVerified = true;
        _verifiedIdToken = "bypass";
        error = "";
      });
      return;
    }

    final formatted = phone.startsWith('+') ? phone : '+234${phone.replaceFirst(RegExp(r'^0'), '')}';
    final idToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PhoneAuthScreen(phone: formatted)),
    );
    if (idToken != null && mounted) {
      setState(() {
        _phoneVerified = true;
        _verifiedIdToken = idToken;
        error = "";
      });
    }
  }
  
  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  Future<void> register() async {
    if (!_phoneVerified || _verifiedIdToken == null) {
      setState(() => error = "Please verify your phone number first");
      return;
    }
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => error = "Full name is required");
      return;
    }
    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      setState(() => error = "Passwords do not match");
      return;
    }
    if (passwordCtrl.text.length < 6) {
      setState(() => error = "Password must be at least 6 characters");
      return;
    }

    setState(() { loading = true; error = ""; });

    try {
      final position = await _getLocation();

      final body = {
        "name": nameCtrl.text.trim(),
        "password": passwordCtrl.text.trim(),
        "role": widget.role,
        "phone": phoneCtrl.text.trim().startsWith('+')
            ? phoneCtrl.text.trim()
            : '+234${phoneCtrl.text.trim().replaceFirst(RegExp(r'^0'), '')}',
        "idToken": _verifiedIdToken,
        if (emailCtrl.text.trim().isNotEmpty) "email": emailCtrl.text.trim(),
        if (position != null)
          "location": {
            "type": "Point",
            "coordinates": [position.longitude, position.latitude],
          },
      };

      final res = await ApiService.post("/auth/register", body);

      if (!mounted) return;

      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"] ?? {});
      if (res["rider"] != null) await Session.saveRiderProfile(res["rider"]);

      setState(() { loading = false; _registered = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceAll("Exception: ", "");
        loading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (widget.role == "rider") {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => VehicleInfoScreen(onCompleted: () => widget.onRegister?.call())));
      return;
    }
    if (widget.role == "vendor") {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => VendorOnboardingScreen(onCompleted: () => widget.onRegister?.call())));
      return;
    }
    widget.onRegister?.call();
  }

  String get _roleLabel => widget.role == "rider" ? "Rider" : widget.role == "vendor" ? "Vendor" : "Customer";
  Color get _roleColor => widget.role == "rider" ? Colors.orange : widget.role == "vendor" ? Colors.green : const Color(0xFFDC2626);
  IconData get _roleIcon => widget.role == "rider" ? Icons.delivery_dining : widget.role == "vendor" ? Icons.storefront : Icons.shopping_bag;
  String get _nextStepLabel => widget.role == "rider" ? "Continue to vehicle details" : widget.role == "vendor" ? "Continue to business details" : "Enter the app";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Create $_roleLabel Account"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _registered ? _successView() : _formView(),
      ),
    );
  }

  Widget _successView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        ),
        const SizedBox(height: 24),
        const Text("Account Created!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
          widget.role == "customer"
              ? "You're all set. Tap below to start ordering."
              : widget.role == "rider"
                  ? "Almost there! Add your vehicle details to start delivering."
                  : "Almost there! Complete your business profile to start selling.",
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _roleColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _continue,
            child: Text(_nextStepLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: _roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_roleIcon, color: _roleColor, size: 14),
            const SizedBox(width: 6),
            Text("Signing up as $_roleLabel",
                style: TextStyle(color: _roleColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 24),

        _field("Full Name", nameCtrl, icon: Icons.person_outline),
        const SizedBox(height: 14),

        // Phone + verify button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                enabled: !_phoneVerified,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  suffixIcon: _phoneVerified
                      ? const Icon(Icons.verified, color: Colors.green, size: 20)
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _phoneVerified ? Colors.green : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _roleColor, width: 1.5),
                  ),
                  helperText: _phoneVerified ? "✓ Verified" : "e.g. 08012345678",
                  helperStyle: TextStyle(
                      color: _phoneVerified ? Colors.green : Colors.grey,
                      fontSize: 11),
                ),
              ),
            ),
            if (!_phoneVerified) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _roleColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _verifyPhone,
                  child: const Text("Verify", style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // Email optional
        _field("Email (optional)", emailCtrl,
            icon: Icons.email_outlined, inputType: TextInputType.emailAddress),
        const SizedBox(height: 14),

        // Password
        _passwordField("Password", passwordCtrl, _obscurePassword,
            () => setState(() => _obscurePassword = !_obscurePassword)),
        const SizedBox(height: 14),

        _passwordField("Confirm Password", confirmPasswordCtrl, _obscureConfirm,
            () => setState(() => _obscureConfirm = !_obscureConfirm)),

        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(error,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _phoneVerified ? _roleColor : Colors.grey.shade300,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: loading || !_phoneVerified ? null : register,
            child: loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _phoneVerified ? "Create Account" : "Verify phone to continue",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {IconData? icon, TextInputType? inputType}) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _roleColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _roleColor, width: 1.5),
        ),
      ),
    );
  }
}