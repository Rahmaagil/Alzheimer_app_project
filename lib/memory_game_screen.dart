import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _cards = [];
  final List<int> _flippedIndices = [];
  final List<int> _matchedIndices = [];
  int _score = 0;
  int _moves = 0;
  bool _isProcessing = false;
  bool _gameStarted = false;
  int _timeElapsed = 0;
  Timer? _timer;
  final List<Map<String, dynamic>> _allCards = [
    {'icon': Icons.favorite, 'color': const Color(0xFFE91E63), 'name': 'Cœur'},
    {'icon': Icons.star, 'color': const Color(0xFFFFD700), 'name': 'Étoile'},
    {'icon': Icons.home, 'color': const Color(0xFF4CAF50), 'name': 'Maison'},
    {'icon': Icons.pets, 'color': const Color(0xFFFF9800), 'name': 'Animal'},
    {'icon': Icons.music_note, 'color': const Color(0xFF9C27B0), 'name': 'Musique'},
    {'icon': Icons.wb_sunny, 'color': const Color(0xFFFFEB3B), 'name': 'Soleil'},
    {'icon': Icons.water_drop, 'color': const Color(0xFF2196F3), 'name': 'Eau'},
    {'icon': Icons.eco, 'color': const Color(0xFF4CAF50), 'name': 'Plante'},
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    final random = Random();
    final selectedCards = List<Map<String, dynamic>>.from(_allCards)..shuffle(random);
    final gameCards = selectedCards.take(8).toList();
    final duplicatedCards = [...gameCards, ...gameCards]..shuffle(random);

    setState(() {
      _cards.clear();
      _cards.addAll(duplicatedCards);
      _flippedIndices.clear();
      _matchedIndices.clear();
      _score = 0;
      _moves = 0;
      _isProcessing = false;
      _gameStarted = true;
      _timeElapsed = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _timeElapsed++);
    });
  }

  Future<void> _onCardTap(int index) async {
    if (_isProcessing) return;
    if (_flippedIndices.contains(index)) return;
    if (_matchedIndices.contains(index)) return;
    if (_flippedIndices.length >= 2) return;

    setState(() => _flippedIndices.add(index));

    if (_flippedIndices.length == 2) {
      setState(() => _moves++);
      _isProcessing = true;

      await Future.delayed(const Duration(milliseconds: 800));

      final firstCard = _cards[_flippedIndices[0]];
      final secondCard = _cards[_flippedIndices[1]];

      if (firstCard['icon'] == secondCard['icon']) {
        setState(() {
          _matchedIndices.addAll(_flippedIndices);
          _score += 10;
        });

        if (_matchedIndices.length == _cards.length) {
          _timer?.cancel();
          _saveScore();
        }
      }

      setState(() => _flippedIndices.clear());
      _isProcessing = false;
    }
  }

  Future<void> _saveScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('game_scores')
          .add({
        'gameType': 'memory',
        'score': _score,
        'moves': _moves,
        'time': _timeElapsed,
        'playedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("[MemoryGame] Erreur sauvegarde: $e");
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mémoire',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AppDecorationWidgets.buildDecoCircles(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
            ),
            child: !_gameStarted
                ? _buildStartScreen()
                : _matchedIndices.length == _cards.length
                    ? _buildWinScreen()
                    : _buildGameScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Jeu de Mémoire',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trouvez les paires identiques\npour améliorer votre mémoire',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: ElevatedButton(
              onPressed: _initializeGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
              ),
              child: const Text(
                'Commencer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Temps', _formatTime(_timeElapsed), Icons.timer),
              _buildStat('Coups', '$_moves', Icons.touch_app),
              _buildStat('Score', '$_score', Icons.star),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final isFlipped = _flippedIndices.contains(index) || _matchedIndices.contains(index);
                return _buildCard(index, isFlipped);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E5AAC),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildCard(int index, bool isFlipped) {
    final card = _cards[index];

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: isFlipped ? card['color'] : const Color(0xFF4A90E2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isFlipped
                  ? card['color'].withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isFlipped
              ? Icon(card['icon'], color: Colors.white, size: 36)
              : const Icon(Icons.question_mark, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildWinScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.4),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 30),
          const Text(
            'Félicitations !',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildResultRow('Score', '$_score', Icons.star, const Color(0xFFFFD700)),
                const SizedBox(height: 16),
                _buildResultRow('Coups', '$_moves', Icons.touch_app, const Color(0xFF4A90E2)),
                const SizedBox(height: 16),
                _buildResultRow('Temps', _formatTime(_timeElapsed), Icons.timer, const Color(0xFFFF9800)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ElevatedButton(
                  onPressed: _initializeGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  ),
                  child: const Text(
                    'Rejouer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  ),
                  child: const Text(
                    'Quitter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)),
        ),
      ],
    );
  }
}
