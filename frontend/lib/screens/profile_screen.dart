import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String apiUrl = 'https://naila-teaching-alphabets.onrender.com';
  static const String fallbackApiUrl = 'https://naila-teaching-alphabets.onrender.com';

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  String _currentUsername = '';
  String? _avatarUrl;
  XFile? _selectedAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('vaila_user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      setState(() {
        _currentUsername = user['username'] ?? '';
        _usernameController.text = user['username'] ?? '';
        _emailController.text = user['email'] ?? '';
        _avatarUrl = user['avatar_url'];
      });
    }
  }

  void _pickAvatar() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _selectedAvatar = img);
    }
  }

  void _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final targetUrl = kIsWeb ? '$fallbackApiUrl/api/auth/update-profile' : '$apiUrl/api/auth/update-profile';
      final request = http.MultipartRequest('POST', Uri.parse(targetUrl));

      request.fields['username'] = _usernameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['current_username'] = _currentUsername;

      if (_selectedAvatar != null) {
        final bytes = await _selectedAvatar!.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('avatar', bytes, filename: 'avatar.png'),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vaila_user', jsonEncode(data['user']));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      print('Update error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              Text(
                "My Profile",
                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 24),

              // Avatar Circle
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E293B),
                        border: Border.all(color: const Color(0xFF4361EE), width: 3),
                      ),
                      child: Center(
                        child: Text(
                          _usernameController.text.isNotEmpty ? _usernameController.text[0].toUpperCase() : 'V',
                          style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFF4361EE), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Username Field
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Username",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF38BDF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Email Field
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Email Address",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Save Profile Changes", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: Text("Logout Account", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
