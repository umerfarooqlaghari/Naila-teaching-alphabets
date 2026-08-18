import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'waiting_approval_screen.dart';

class PaymentUploadScreen extends StatefulWidget {
  final String username;
  final String email;
  final String password;

  const PaymentUploadScreen({
    super.key,
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  State<PaymentUploadScreen> createState() => _PaymentUploadScreenState();
}

class _PaymentUploadScreenState extends State<PaymentUploadScreen> {
  static const String apiUrl = 'https://naila-teaching-alphabets.onrender.com';
  static const String fallbackApiUrl = 'https://naila-teaching-alphabets.onrender.com';

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _pickScreenshot() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        _selectedImage = img;
        _errorMessage = null;
      });
    }
  }

  void _submitRegistration() async {
    if (_selectedImage == null) {
      setState(() => _errorMessage = "Please upload bank payment screenshot before submitting");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final targetUrl = kIsWeb ? '$fallbackApiUrl/api/auth/register' : '$apiUrl/api/auth/register';
      final request = http.MultipartRequest('POST', Uri.parse(targetUrl));

      request.fields['username'] = widget.username;
      request.fields['email'] = widget.email;
      request.fields['password'] = widget.password;

      final bytes = await _selectedImage!.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'screenshot',
          bytes,
          filename: 'registration_proof_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => WaitingApprovalScreen(username: widget.username)),
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = data['detail'] ?? data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() => _errorMessage = "Server timeout waking up backend. Please tap Submit again in a few seconds.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Registration Fee Payment", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bank Account Details Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 28),
                            const SizedBox(width: 10),
                            Text("Bank Payment Details", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text("Pay registration fee to start learning:", style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13)),
                        const SizedBox(height: 10),
                        _buildDetailRow("Bank Name:", "Meezan Bank"),
                        _buildDetailRow("Account Title:", "Vaila Teaching System"),
                        _buildDetailRow("Account / IBAN:", "PK92 MEZN 0001 0203 0405 0607"),
                        _buildDetailRow("Registration Fee:", "\$10 / Rs. 2,000"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        border: Border.all(color: Colors.redAccent),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_errorMessage!, style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Upload Payment Screenshot Box
                  GestureDetector(
                    onTap: _pickScreenshot,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedImage != null ? Colors.greenAccent : const Color(0xFF4361EE),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedImage != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                            color: _selectedImage != null ? Colors.greenAccent : const Color(0xFF4361EE),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedImage != null ? "Screenshot Attached Successfully!" : "Upload Payment Screenshot",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedImage != null ? Colors.greenAccent : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedImage != null ? "Tap to change image" : "Select bank transfer receipt from gallery",
                            style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("Submit Payment for Approval ➔", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
