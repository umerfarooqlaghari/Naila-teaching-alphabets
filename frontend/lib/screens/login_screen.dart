import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'waiting_approval_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String apiUrl = 'https://naila-teaching-alphabets.onrender.com';
  static const String fallbackApiUrl = 'https://naila-teaching-alphabets.onrender.com';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final targetUrl = kIsWeb ? '$fallbackApiUrl/api/auth/login' : '$apiUrl/api/auth/login';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email_or_username': input,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vaila_token', data['token'] ?? 'token');
        await prefs.setString('vaila_user', jsonEncode(data['user']));

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        // Handle pending approval or monthly fee lock
        if (data['is_approved'] == false) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WaitingApprovalScreen(username: input)),
          );
        } else if (data['requires_monthly_payment'] == true) {
          _showMonthlyPaymentModal(input);
        } else {
          setState(() => _errorMessage = data['detail'] ?? data['message'] ?? 'Login failed');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection timeout / server waking up. Please try signing in again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMonthlyPaymentModal(String username) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonthlyPaymentModal(username: username),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Forgot Password", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          "Please contact Vaila Admin at Admin@vaila.com to reset your password or upload fee proof.",
          style: GoogleFonts.outfit(color: Colors.grey.shade300, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361EE)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF4361EE)]),
                      ),
                      child: Center(
                        child: Text("V", style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Welcome Back",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8)),
                  ),
                  Text(
                    "Sign in to continue your phonetics learning",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13)),
                    ),

                  // Username/Email Field
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Username or Email",
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text("Forgot password?", style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 13)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4361EE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("Sign In ➔", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ", style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Monthly Payment Modal ───────────────────────────────────────────────────
class MonthlyPaymentModal extends StatefulWidget {
  final String username;
  const MonthlyPaymentModal({super.key, required this.username});

  @override
  State<MonthlyPaymentModal> createState() => _MonthlyPaymentModalState();
}

class _MonthlyPaymentModalState extends State<MonthlyPaymentModal> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  String _selectedMonth = 'August';
  String _selectedYear = '2026';

  void _pickScreenshot() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _selectedImage = img);
    }
  }

  void _submitMonthlyPayment() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);

    try {
      final targetUrl = 'https://naila-teaching-alphabets.onrender.com/api/auth/upload-monthly-payment';
      final request = http.MultipartRequest('POST', Uri.parse(targetUrl));

      request.fields['username'] = widget.username;
      request.fields['month'] = _selectedMonth;
      request.fields['year'] = _selectedYear;

      final bytes = await _selectedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('screenshot', bytes, filename: 'monthly_fee.png'),
      );

      final res = await request.send();
      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Monthly fee screenshot submitted! Admin will reactivate your account shortly.")),
        );
      }
    } catch (e) {
      print('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24, left: 24, right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text("Monthly Fee Lock 💳", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 8),
          Text(
            "Please pay your fee for this month and upload screenshot to reactivate your account.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4361EE)),
              ),
              child: _selectedImage != null
                  ? Center(child: Text("✅ Photo Selected", style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold)))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF38BDF8), size: 36),
                        const SizedBox(height: 6),
                        Text("Tap to Attach Payment Proof", style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: (_selectedImage == null || _isUploading) ? null : _submitMonthlyPayment,
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Submit Payment Proof", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
