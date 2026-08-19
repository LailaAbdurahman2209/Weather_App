import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyChallengeCard extends StatefulWidget {
  final double actualHighTemp;
  final bool isDarkMode;

  const DailyChallengeCard({
    Key? key,
    required this.actualHighTemp,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  final TextEditingController _guessController = TextEditingController();
  bool _hasGuessedToday = false;
  int _streak = 0;
  int _score = 0;
  String _feedback = "";

  @override
  void initState() {
    super.initState();
    _loadChallengeData();
  }

  Future<void> _loadChallengeData() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final String? lastGuessDate = prefs.getString('last_guess_date');

    setState(() {
      _streak = prefs.getInt('challenge_streak') ?? 0;
      _score = prefs.getInt('challenge_score') ?? 0;
      
      if (lastGuessDate == today) {
        _hasGuessedToday = true;
        _feedback = "You've already guessed today! Come back tomorrow.";
      }
    });
  }

  Future<void> _submitGuess() async {
    final guessText = _guessController.text;
    if (guessText.isEmpty) return;

    final double? guess = double.tryParse(guessText);
    if (guess == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);

    double difference = (widget.actualHighTemp - guess).abs();
    int pointsEarned = 0;
    
    if (difference <= 1.0) {
      pointsEarned = 10;
      _streak++;
      _feedback = "Spot on! 🎯 +10 pts! The high is ${widget.actualHighTemp}°C.";
    } else if (difference <= 3.0) {
      pointsEarned = 5;
      _streak++;
      _feedback = "So close! 🔥 +5 pts! The high is ${widget.actualHighTemp}°C.";
    } else {
      _streak = 0; 
      _feedback = "Not quite! 🥶 The high is ${widget.actualHighTemp}°C. Streak reset.";
    }

    _score += pointsEarned;

    await prefs.setString('last_guess_date', today);
    await prefs.setInt('challenge_streak', _streak);
    await prefs.setInt('challenge_score', _score);

    setState(() {
      _hasGuessedToday = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDarkMode ? Colors.white : Colors.black87;
    final bgColor = widget.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.isDarkMode ? Colors.white24 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Daily Challenge 🏆", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("🔥 $_streak | ⭐ $_score", style: TextStyle(color: color, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 15),
          if (!_hasGuessedToday) ...[
            Text("Guess today's high temperature!", style: TextStyle(color: color)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guessController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: color),
                    decoration: InputDecoration(
                      hintText: "e.g. 24",
                      hintStyle: TextStyle(color: color.withOpacity(0.5)),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.black26 : Colors.white54,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _submitGuess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Submit", style: TextStyle(color: Colors.white)),
                )
              ],
            )
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.black26 : Colors.white54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_feedback, style: TextStyle(color: color, fontSize: 15)),
            )
          ]
        ],
      ),
    );
  }
}