import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vibration/vibration.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AlphabetItem {
  final String id;
  final String letter;
  final String sound;
  final String word;
  final String speechText;
  final String tip;

  AlphabetItem({
    required this.id,
    required this.letter,
    required this.sound,
    required this.word,
    required this.speechText,
    required this.tip,
  });
}

class VailaHomeScreen extends StatefulWidget {
  const VailaHomeScreen({super.key});

  @override
  State<VailaHomeScreen> createState() => _VailaHomeScreenState();
}

class _VailaHomeScreenState extends State<VailaHomeScreen>
    with TickerProviderStateMixin {
  static const String apiUrl = 'https://naila-teaching-alphabets.onrender.com';
  static const String fallbackApiUrl = 'https://naila-teaching-alphabets.onrender.com';

  final List<AlphabetItem> _alphabets = [
    AlphabetItem(
        id: 'a',
        letter: 'a',
        sound: 'A',
        word: 'Apple',
        speechText: 'A',
        tip: 'Say Letter A!'),
    AlphabetItem(
        id: 'b',
        letter: 'b',
        sound: 'B',
        word: 'Ball',
        speechText: 'B',
        tip: 'Say Letter B!'),
    AlphabetItem(
        id: 'c',
        letter: 'c',
        sound: 'C',
        word: 'Cat',
        speechText: 'C',
        tip: 'Say Letter C!'),
    AlphabetItem(
        id: 'd',
        letter: 'd',
        sound: 'D',
        word: 'Dog',
        speechText: 'D',
        tip: 'Say Letter D!'),
    AlphabetItem(
        id: 'e',
        letter: 'e',
        sound: 'E',
        word: 'Elephant',
        speechText: 'E',
        tip: 'Say Letter E!'),
  ];

  int _currentIndex = 0;
  AlphabetItem get _currentAlphabet => _alphabets[_currentIndex];

  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  late stt.SpeechToText _speechToText;
  bool _speechToTextAvailable = false;
  String _recognizedWords = '';

  bool _isSpeaking3x = false;
  int _speechCount = 0;

  bool _isReadyToSpeak = false;
  bool _isListeningWindow = false;
  int _timeLeft = 5;

  bool _voiceDetected = false;
  bool _isEvaluating = false;
  Map<String, dynamic>? _evalResult;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  Timer? _voiceStopTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  double _peakVolumeDb = -160.0;
  bool _voiceDetectedFlag = false;
  bool _cancelTtsLoop = false;

  String _studentName = 'Learner';

  @override
  void initState() {
    super.initState();
    _loadLearnerName();
    _initTts();
    _initAudioStream();
    _initSpeechToText();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _loadLearnerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('vaila_user');
      if (userStr != null) {
        final userObj = jsonDecode(userStr);
        if (userObj['username'] != null && (userObj['username'] as String).isNotEmpty) {
          if (mounted) {
            setState(() {
              _studentName = userObj['username'];
            });
          }
        }
      }
    } catch (e) {
      print('Learner name load notice: $e');
    }
  }

  void _handleLogout() async {
    _cancelTtsLoop = true;
    try { _flutterTts.stop(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _initSpeechToText() async {
    try {
      _speechToText = stt.SpeechToText();
      _speechToTextAvailable = await _speechToText.initialize(
        onError: (err) => print('Speech recognition error: $err'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );
    } catch (e) {
      print('SpeechToText init exception: $e');
    }
  }

  void _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setPitch(1.0);
  }

  void _initAudioStream() {
    try {
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!_isListeningWindow || _voiceDetectedFlag) return;
        final db = amp.current;
        if (db > _peakVolumeDb) _peakVolumeDb = db;

        const double silenceThresholdDb = -32.0;
        if (db > silenceThresholdDb && !_voiceDetectedFlag) {
          _voiceDetectedFlag = true;
          if (mounted) {
            setState(() {
              _voiceDetected = true;
            });
          }

          _voiceStopTimer?.cancel();
          _voiceStopTimer = Timer(const Duration(milliseconds: 2000), () {
            _finishDetectionWindow();
          });
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _voiceStopTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    _flutterTts.stop();
    _audioRecorder.dispose();
    try { _speechToText.stop(); } catch (_) {}
    super.dispose();
  }

  void _triggerShake() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 400);
      }
    } catch (_) {}
    _shakeController.forward(from: 0.0);
  }

  void _speakPhoneticSound3Times([VoidCallback? onDone]) async {
    if (_isSpeaking3x) return;
    _cancelTtsLoop = false;

    if (!mounted) return;
    setState(() {
      _isSpeaking3x = true;
      _isReadyToSpeak = false;
      _isListeningWindow = false;
      _evalResult = null;
      _voiceDetected = false;
    });

    try {
      await _flutterTts.stop();
    } catch (_) {}

    for (int i = 1; i <= 3; i++) {
      if (!mounted || _cancelTtsLoop) return;
      setState(() {
        _speechCount = i;
      });

      try {
        _flutterTts.speak(_currentAlphabet.speechText);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 1400));
    }

    if (!mounted || _cancelTtsLoop) return;
    setState(() {
      _isSpeaking3x = false;
      _speechCount = 0;
      if (onDone != null) {
        onDone();
      } else {
        _isReadyToSpeak = true;
      }
    });
  }

  void _startDetectionWindow() async {
    _countdownTimer?.cancel();
    _voiceStopTimer?.cancel();

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isReadyToSpeak = false;
      _isListeningWindow = true;
      _timeLeft = 5;
      _evalResult = null;
      _voiceDetected = false;
      _isEvaluating = false;
      _recognizedWords = '';
    });

    _peakVolumeDb = -160.0;
    _voiceDetectedFlag = false;
    _pulseController.repeat(reverse: true);

    if (!_speechToTextAvailable) {
      try {
        _speechToTextAvailable = await _speechToText.initialize();
      } catch (_) {}
    }

    if (_speechToTextAvailable) {
      try {
        await _speechToText.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _recognizedWords = result.recognizedWords;
                if (_recognizedWords.trim().isNotEmpty) {
                  _voiceDetected = true;
                  _voiceDetectedFlag = true;
                }
              });
            }
          },
          partialResults: true,
          listenFor: const Duration(seconds: 6),
          pauseFor: const Duration(seconds: 3),
        );
      } catch (e) {
        print('STT listen error: $e');
      }
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 1) {
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
      } else {
        timer.cancel();
        _voiceStopTimer?.cancel();
        _finishDetectionWindow();
      }
    });
  }

  void _finishDetectionWindow() async {
    _countdownTimer?.cancel();
    _voiceStopTimer?.cancel();
    _pulseController.stop();

    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isListeningWindow = false;
      _isEvaluating = true;
    });

    final bool childSpoke = _recognizedWords.trim().isNotEmpty || _voiceDetectedFlag;

    double score = 0;
    bool passed = false;
    String feedback = '';
    String transcription = '';

    try {
      if (!childSpoke) {
        score = 0.0;
        passed = false;
        feedback = "No voice heard. Please speak letter '${_currentAlphabet.sound}' into the microphone!";
        transcription = "(silent)";
      } else {
        final response = await _sendToBackend('', _currentAlphabet.letter, _recognizedWords);

        if (response != null) {
          score = (response['accuracy'] as num).toDouble();
          passed = response['passed'] ?? false;
          feedback = response['feedback'] ?? '';
          transcription = response['whisper_transcription'] ?? '';
        } else {
          score = 0.0;
          passed = false;
          feedback = "Evaluation notice: Unable to connect to server. Please try again!";
          transcription = "(server connection error)";
        }
      }
    } catch (e) {
      score = 0.0;
      passed = false;
      feedback = "Please speak clearly into the microphone and try again!";
      transcription = "(error)";
    }

    if (!mounted) return;

    setState(() {
      _isEvaluating = false;
      _evalResult = {
        'accuracy': score,
        'passed': passed,
        'feedback': feedback,
        'transcription': transcription,
      };
    });

    if (!passed) {
      _triggerShake();
    }
  }

  Future<Map<String, dynamic>?> _sendToBackend(String audioPath, String targetLetter, String spokenText) async {
    final urls = kIsWeb
        ? ['https://naila-teaching-alphabets.onrender.com', 'http://127.0.0.1:8000', 'http://localhost:8000']
        : ['https://naila-teaching-alphabets.onrender.com', 'http://10.0.2.2:8000', 'http://127.0.0.1:8000', 'http://localhost:8000'];

    for (final baseUrl in urls) {
      try {
        final uri = Uri.parse('$baseUrl/api/evaluate-audio');
        final request = http.MultipartRequest('POST', uri);
        request.fields['target_alphabet'] = targetLetter;
        request.fields['spoken_text'] = spokenText;
        request.fields['student_id'] = _studentName;

        if (audioPath.isNotEmpty) {
          if (kIsWeb) {
            try {
              if (audioPath.startsWith('http') || audioPath.startsWith('blob:')) {
                final res = await http.get(Uri.parse(audioPath)).timeout(const Duration(milliseconds: 2500));
                if ((res.statusCode == 200 || res.statusCode == 0) && res.bodyBytes.isNotEmpty) {
                  request.files.add(
                    http.MultipartFile.fromBytes('file', res.bodyBytes, filename: 'pronunciation.wav'),
                  );
                }
              }
            } catch (e) {
              print('Web blob fetch notice: $e');
            }
          } else {
            try {
              request.files.add(
                await http.MultipartFile.fromPath('file', audioPath),
              );
            } catch (_) {}
          }
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        print('Backend evaluation request error: $e');
      }
    }
    return null;
  }

  void _handleNextAlphabet() {
    _cancelTtsLoop = true;
    try {
      _flutterTts.stop();
    } catch (_) {}

    setState(() {
      _evalResult = null;
      _isListeningWindow = false;
      _isReadyToSpeak = false;
      _voiceDetected = false;
      _isEvaluating = false;
      _currentIndex = (_currentIndex + 1) % _alphabets.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Top Bar Header with Back Button and Logout Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          _cancelTtsLoop = true;
                          try { _flutterTts.stop(); } catch (_) {}
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF38BDF8), size: 22),
                        tooltip: "Back",
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "Vaila Phonics Fun 🎈",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Tap letter → Hear 3× → Speak!",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                        tooltip: "Logout",
                      ),
                    ],
                  ),

                  // Playing 3x Sound Banner
                  if (_isSpeaking3x)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF06B6D4)),
                      ),
                      child: Text(
                        "🔊 \"${_currentAlphabet.sound}\" — $_speechCount of 3...",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF38BDF8),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                  // SLEEK & COMPACT CENTERED ALPHABET CARD
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        if (!_isSpeaking3x && !_isListeningWindow && !_isEvaluating) {
                          _speakPhoneticSound3Times();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 215,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: _evalResult?.containsKey('passed') == true
                                ? (_evalResult!['passed'] ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
                                : (_isListeningWindow ? const Color(0xFFA855F7) : const Color(0xFF38BDF8)),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_evalResult?.containsKey('passed') == true
                                      ? (_evalResult!['passed'] ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
                                      : (_isListeningWindow ? const Color(0xFFA855F7) : const Color(0xFF38BDF8)))
                                  .withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 14,
                              left: 0,
                              right: 0,
                              child: Text(
                                "TAP TO HEAR SOUND",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentAlphabet.letter,
                                    style: GoogleFonts.outfit(
                                      fontSize: 76,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF38BDF8),
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Sound: \"${_currentAlphabet.sound}\"",
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    "(${_currentAlphabet.sound} like ${_currentAlphabet.word})",
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // YOUR TURN BUTTON / MIC DETECTION WINDOW / RESULTS CARD
                  _buildInteractiveBottomSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveBottomSection() {
    if (_isEvaluating) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8)),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF38BDF8)),
            const SizedBox(height: 12),
            Text(
              "Evaluating Speech...",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_evalResult != null) {
      final bool passed = _evalResult!['passed'];
      final double score = _evalResult!['accuracy'];
      final String feedback = _evalResult!['feedback'];

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: passed ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: passed ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  passed ? "GREAT JOB!" : "TRY AGAIN!",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: passed ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Match Score: ${score.toStringAsFixed(1)}%",
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              feedback,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),

            if (passed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _handleNextAlphabet,
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  label: Text("NEXT LETTER ➔", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _speakPhoneticSound3Times(),
                  icon: const Icon(Icons.replay_rounded, color: Colors.white),
                  label: Text("TRY AGAIN 🔄", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
          ],
        ),
      );
    }

    if (_isListeningWindow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFA855F7), width: 2),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_rounded, color: Color(0xFFA855F7), size: 22),
                const SizedBox(width: 6),
                Text(
                  "Listening... say \"${_currentAlphabet.sound}\"",
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),

            LinearProgressIndicator(
              value: _timeLeft / 12,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: const Color(0xFFA855F7),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text("${_timeLeft}s remaining", style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 12),

            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _finishDetectionWindow,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _voiceDetected ? const Color(0xFF10B981) : const Color(0xFFA855F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _voiceDetected ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _voiceDetected ? "Voice Heard! Processing..." : "Waiting for your voice...",
              style: GoogleFonts.outfit(color: _voiceDetected ? const Color(0xFF10B981) : const Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_isReadyToSpeak) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _startDetectionWindow,
          icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
          label: Text("YOUR TURN — SPEAK NOW! 🎤", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF38BDF8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _speakPhoneticSound3Times(),
        icon: const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8)),
        label: Text("TAP LETTER TO START 👆", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
      ),
    );
  }
}
