import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../widgets/mic_verification_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlaybackService _audioService = AudioPlaybackService();
  
  int _currentAlphabetIndex = 0; // 0 = A, 1 = B ... 25 = Z
  int _tapCount = 0; // Tracks taps (0 to 3)
  final int _maxTaps = 3;

  final List<String> _alphabets = List.generate(26, (index) => String.fromCharCode(65 + index));
  final Map<String, String> _exampleWords = {
    'A': 'Apple 🍎', 'B': 'Ball ⚽', 'C': 'Cat 🐱', 'D': 'Dog 🐶', 'E': 'Elephant 🐘',
    'F': 'Fish 🐟', 'G': 'Giraffe 🦒', 'H': 'Hat 🎩', 'I': 'Ice Cream 🍦', 'J': 'Juice 🧃',
    'K': 'Kite 🪁', 'L': 'Lion 🦁', 'M': 'Monkey 🐒', 'N': 'Nest 🪹', 'O': 'Owl 🦉',
    'P': 'Penguin 🐧', 'Q': 'Queen 👑', 'R': 'Rabbit 🐰', 'S': 'Sun ☀️', 'T': 'Tiger 🐯',
    'U': 'Umbrella ☂️', 'V': 'Violin 🎻', 'W': 'Watch ⌚', 'X': 'Xylophone 🎼', 'Y': 'Yacht ⛵', 'Z': 'Zebra 🦓'
  };

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  String get _currentLetter => _alphabets[_currentAlphabetIndex];

  void _onAlphabetTap() async {
    if (_tapCount < _maxTaps) {
      setState(() {
        _tapCount++;
      });

      // Play reference voice audio
      await _audioService.playAlphabetSound(_currentLetter);

      // If user reaches max 3 taps, trigger speaking turn
      if (_tapCount == _maxTaps) {
        Future.delayed(const Duration(milliseconds: 600), () {
          _openMicVerificationSheet();
        });
      }
    }
  }

  void _openMicVerificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MicVerificationSheet(
        targetLetter: _currentLetter,
        onSuccessNext: _proceedToNextAlphabet,
      ),
    );
  }

  void _proceedToNextAlphabet() {
    // Show success banner & advance to next alphabet
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFE8F5E9),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 36),
            const SizedBox(width: 10),
            Text(
              "Great Job!",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ],
        ),
        content: Text(
          "Your voice matched letter '$_currentLetter' perfectly! Unlocking next alphabet...",
          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _tapCount = 0;
                if (_currentAlphabetIndex < 25) {
                  _currentAlphabetIndex++;
                } else {
                  _currentAlphabetIndex = 0; // Completed A-Z loop!
                }
              });
            },
            child: Text(
              "Next Alphabet →",
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAlphabetDirectly(int index) {
    setState(() {
      _currentAlphabetIndex = index;
      _tapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Deaf Alphabets Voice Learn (A-Z)",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B2D42),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Alphabet Selector Carousel A-Z
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _alphabets.length,
                itemBuilder: (ctx, idx) {
                  final bool isSelected = idx == _currentAlphabetIndex;
                  return GestureDetector(
                    onTap: () => _selectAlphabetDirectly(idx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4361EE) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF4361EE).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          _alphabets[idx],
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF2B2D42),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const Spacer(),

            // Main Interactive Big Alphabet Card (Tap 1-3 times)
            GestureDetector(
              onTap: _onAlphabetTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 260,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4361EE).withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: _tapCount == _maxTaps ? Colors.orangeAccent : const Color(0xFF4361EE).withOpacity(0.2),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentLetter,
                          style: GoogleFonts.outfit(
                            fontSize: 120,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF4361EE),
                          ),
                        ),
                        Text(
                          _exampleWords[_currentLetter] ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Speaker Icon Badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F7FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: Color(0xFF4361EE), size: 24),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tap Progress Counter Indicator (Max 3 taps)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_maxTaps, (index) {
                final bool isTapped = index < _tapCount;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 32,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isTapped ? const Color(0xFF4361EE) : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            Text(
              _tapCount < _maxTaps
                  ? "Tap card to hear voice (${_tapCount}/$_maxTaps taps)"
                  : "3 Taps reached! Your turn to speak!",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _tapCount == _maxTaps ? Colors.orangeAccent : Colors.grey.shade600,
              ),
            ),

            const Spacer(),

            // Explicit Speak Button (Activates on 3rd tap or click)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tapCount == _maxTaps ? Colors.orangeAccent : const Color(0xFF4361EE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                  ),
                  onPressed: _openMicVerificationSheet,
                  icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                  label: Text(
                    _tapCount == _maxTaps ? "Speak Now!" : "Practice Voice for '$_currentLetter'",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
