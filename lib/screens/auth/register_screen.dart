import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../utils/session.dart';
import '../rider/vehicle_info_screen.dart';
import '../vendor/vendor_onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  final VoidCallback? onRegister;

  const RegisterScreen({
    super.key,
    required this.role,
    this.onRegister,
  });

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
  bool _registered = false; // ✅ tracks successful registration
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

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services are disabled");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> register() async {
    // ✅ Validate password match before hitting the API
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
      if (nameCtrl.text.isEmpty ||
          emailCtrl.text.isEmpty ||
          passwordCtrl.text.isEmpty ||
          phoneCtrl.text.isEmpty) {
        throw Exception("All fields are required");
      }

      final position = await _getLocation();

      final res = await ApiService.post("/auth/register", {
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "password": passwordCtrl.text.trim(),
        "role": widget.role,
        "phone": phoneCtrl.text.trim(),
        "location": {
          "type": "Point",
          "coordinates": [position.longitude, position.latitude]
        }
      });

      if (!mounted) return;

      await Session.saveToken(res["token"]);
      await Session.saveUser(res["user"] ?? {});
      if (res["rider"] != null) {
        await Session.saveRiderProfile(res["rider"]);
      }

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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleInfoScreen(
            onCompleted: () => widget.onRegister?.call(),
          ),
        ),
      );
      return;
    }

    if (widget.role == "vendor") {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorOnboardingScreen(
            onCompleted: () => widget.onRegister?.call(),
          ),
        ),
      );
      return;
    }

    // Customer — go straight to app
    widget.onRegister?.call();
  }

  String get _roleLabel {
    switch (widget.role) {
      case "rider": return "Rider";
      case "vendor": return "Vendor";
      default: return "Customer";
    }
  }

  Color get _roleColor {
    switch (widget.role) {
      case "rider": return Colors.orange;
      case "vendor": return Colors.green;
      default: return const Color(0xFFDC2626);
    }
  }

  IconData get _roleIcon {
    switch (widget.role) {
      case "rider": return Icons.delivery_dining;
      case "vendor": return Icons.storefront;
      default: return Icons.shopping_bag;
    }
  }

  String get _nextStepLabel {
    switch (widget.role) {
      case "rider": return "Continue to vehicle details";
      case "vendor": return "Continue to business details";
      default: return "Enter the app";
    }
  }

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

  // ── Success state ──────────────────────────────────
  Widget _successView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle,
              color: Colors.green, size: 48),
        ),
        const SizedBox(height: 24),
        const Text(
          "Account Created!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
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
              backgroundColor: _roleColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _continue,
            child: Text(
              _nextStepLabel,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ── Form ───────────────────────────────────────────
  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_roleIcon, color: _roleColor, size: 14),
              const SizedBox(width: 6),
              Text(
                "Signing up as $_roleLabel",
                style: TextStyle(
                    color: _roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _field("Full Name", nameCtrl, icon: Icons.person_outline),
        const SizedBox(height: 14),
        _field("Email", emailCtrl,
            icon: Icons.email_outlined,
            inputType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _field("Phone Number", phoneCtrl,
            icon: Icons.phone_outlined,
            inputType: TextInputType.phone),
        const SizedBox(height: 14),

        // ── Password ──────────────────────────────────
        TextField(
          controller: passwordCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Confirm Password ──────────────────────────
        TextField(
          controller: confirmPasswordCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: "Confirm Password",
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _roleColor, width: 1.5),
            ),
          ),
        ),

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
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _roleColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: loading ? null : register,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    "Create Account",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    IconData? icon,
    bool obscure = false,
    TextInputType? inputType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
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