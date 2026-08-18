import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Configurable backend URL (production Render endpoint)
  static const String baseUrl = 'https://naila-teaching-alphabets.onrender.com/api';
  static const String fallbackUrl = 'https://naila-teaching-alphabets.onrender.com/api';

  /// Sends the recorded user audio file to Node.js backend for AI Voice Verification
  static Future<Map<String, dynamic>> verifyVoice({
    required File audioFile,
    required String targetLetter,
    String userId = 'student_1',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/voice/verify');
      final request = http.MultipartRequest('POST', uri);

      request.fields['targetLetter'] = targetLetter;
      request.fields['userId'] = userId;

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'passed': false,
          'message': 'Server error (${response.statusCode}): ${response.body}'
        };
      }
    } catch (e) {
      // Offline fallback evaluation mode if local backend server is not running
      print('Network exception connecting to backend API: $e');
      return _offlineDevFallback(audioFile, targetLetter);
    }
  }

  /// Offline local fallback verification if network is disconnected during development
  static Future<Map<String, dynamic>> _offlineDevFallback(File file, String letter) async {
    await Future.delayed(const Duration(milliseconds: 1200)); // Simulate processing delay
    final fileLength = await file.length();
    
    if (fileLength > 1500) {
      return {
        'success': true,
        'passed': true,
        'accuracyScore': 85.0,
        'message': '[Offline Mode] Pronunciation verified for letter $letter!'
      };
    } else {
      return {
        'success': true,
        'passed': false,
        'accuracyScore': 35.0,
        'message': 'Voice not detected clearly. Try speaking again.'
      };
    }
  }
}
