import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  final String username;
  const WaitingApprovalScreen({super.key, required this.username});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  static const String apiUrl = 'http://10.0.2.2:8000';
  static const String fallbackApiUrl = 'http://localhost:8000';

  Timer? _statusTimer;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    // Poll backend every 3 seconds to check if Admin has approved registration
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkApprovalStatus();
    });
  }

  void _checkApprovalStatus() async {
    try {
      final targetUrl = kIsWeb ? '$fallbackApiUrl/api/auth/check-status/${widget.username}' : '$apiUrl/api/auth/check-status/${widget.username}';
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['is_approved'] == true && !_isApproved) {
          _isApproved = true;
          _statusTimer?.cancel();

          if (!mounted) return;
          _showApprovalPopup();
        }
      }
    } catch (_) {}
  }

  void _showApprovalPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Registration Approved!",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          "Your registration has been approved by Vaila Admin! Now you can login with your credentials to start learning.",
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text("Login Now ➔", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF4361EE).withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                    ],
                  ),
                  child: const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 4),
                ),
                const SizedBox(height: 32),
                Text(
                  "Waiting for Confirmation...",
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your registration payment screenshot has been submitted to Admin.\nAs soon as Admin approves your payment, you will get an instant notification to login!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 40),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4361EE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF38BDF8)),
                  label: Text("Back to Login", style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
