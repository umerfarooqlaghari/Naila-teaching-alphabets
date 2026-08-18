import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../services/api_service.dart';
import '../services/recording_service.dart';

class MicVerificationSheet extends StatefulWidget {
  final String targetLetter;
  final VoidCallback onSuccessNext;

  const MicVerificationSheet({
    super.key,
    required this.targetLetter,
    required this.onSuccessNext,
  });

  @override
  State<MicVerificationSheet> createState() => _MicVerificationSheetState();
}

class _MicVerificationSheetState extends State<MicVerificationSheet> {
  final RecordingService _recordingService = RecordingService();
  bool _isRecording = false;
  bool _isEvaluating = false;
  int _secondsLeft = 3;
  Timer? _timer;
  String _statusMessage = "Tap the microphone and speak out loud!";

  @override
  void dispose() {
    _timer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  void _startMicRecording() async {
    setState(() {
      _isRecording = true;
      _secondsLeft = 3;
      _statusMessage = "Listening to your voice... Speak '${widget.targetLetter}' now!";
    });

    await _recordingService.startRecording();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        _stopAndVerify();
      }
    });
  }

  void _stopAndVerify() async {
    setState(() {
      _isRecording = false;
      _isEvaluating = true;
      _statusMessage = "Verifying your voice with AI model...";
    });

    final File? audioFile = await _recordingService.stopRecording();

    if (audioFile == null) {
      _handleFailure("Audio recording failed. Please try again.");
      return;
    }

    // Call Node.js Backend API
    final result = await ApiService.verifyVoice(
      audioFile: audioFile,
      targetLetter: widget.targetLetter,
    );

    if (!mounted) return;

    final bool passed = result['passed'] ?? false;
    final String message = result['message'] ?? 'Voice verification finished.';

    if (passed) {
      // SUCCESS!
      Navigator.of(context).pop(); // Close sheet
      widget.onSuccessNext(); // Trigger next alphabet progression in main screen
    } else {
      // FAILURE - Trigger Vibration & Pop-up Alert Dialog as required!
      _handleFailure(message);
    }
  }

  void _handleFailure(String message) async {
    setState(() {
      _isEvaluating = false;
      _statusMessage = "Voice mismatch detected.";
    });

    // 1. Phone Vibration
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 600);
      }
    } catch (e) {
      print('Vibration trigger notice: $e');
    }

    if (!mounted) return;

    // 2. Pop-up Alert Dialog: "Your voice doesn't match, try again"
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFFFF0F0),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
              const SizedBox(width: 10),
              Text(
                "Voice Mismatch",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your voice doesn't match the alphabet '${widget.targetLetter}'. Please try again!",
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text(
                "Try Again",
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "It's Your Turn to Speak!",
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2B2D42),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Say the letter '${widget.targetLetter}' clearly into the microphone.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 30),

          // Big Mic Button with Pulse / Countdown animation
          GestureDetector(
            onTap: (_isRecording || _isEvaluating) ? null : _startMicRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [Colors.redAccent, Colors.deepOrangeAccent]
                      : (_isEvaluating
                          ? [Colors.orangeAccent, Colors.amber]
                          : [const Color(0xFF4EA8DE), const Color(0xFF4895EF)]),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.redAccent : const Color(0xFF4895EF)).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Center(
                child: _isEvaluating
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                    : (_isRecording
                        ? Text(
                            "$_secondsLeft s",
                            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : const Icon(Icons.mic_rounded, size: 54, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _isRecording ? Colors.redAccent : const Color(0xFF2B2D42),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
