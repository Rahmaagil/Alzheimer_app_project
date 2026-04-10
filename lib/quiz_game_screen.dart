import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizGameScreen extends StatefulWidget {
  const QuizGameScreen({super.key});

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int _totalQuestions = 10;
  bool _gameStarted = false;
  bool _answered = false;
  int? _selectedAnswer;
  bool _isCorrect = false;
  int _timeRemaining = 15;
  Timer? _timer;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Quelle est la capitale de la France ?',
      'answers': ['Paris', 'Lyon', 'Marseille', 'Nice'],
      'correct': 0,
    },
    {
      'question': 'Quelle couleur obtient-on en mélangeant bleu et jaune ?',
      'answers': ['Vert', 'Orange', 'Violet', 'Rose'],
      'correct': 0,
    },
    {
      'question': 'Combien de jours compte une année normale ?',
      'answers': ['365', '366', '364', '360'],
      'correct': 0,
    },
    {
      'question': 'Quel animal est connu comme le meilleur ami de l\'homme ?',
      'answers': ['Chien', 'Chat', 'Lapin', 'Oiseau'],
      'correct': 0,
    },
    {
      'question': 'Quelle planète est la plus proche du Soleil ?',
      'answers': ['Mercure', 'Vénus', 'Mars', 'Jupiter'],
      'correct': 0,
    },
    {
      'question': 'Quel est le plus grand océan du monde ?',
      'answers': ['Pacifique', 'Atlantique', 'Indien', 'Arctique'],
      'correct': 0,
    },
    {
      'question': 'Combien de saisons y a-t-il dans une année ?',
      'answers': ['4', '3', '5', '6'],
      'correct': 0,
    },
    {
      'question': 'Quel fruit est jaune et allongé ?',
      'answers': ['Banane', 'Pomme', 'Orange', 'Raisin'],
      'correct': 0,
    },
    {
      'question': 'Quelle est la couleur du ciel par beau temps ?',
      'answers': ['Bleu', 'Vert', 'Jaune', 'Rouge'],
      'correct': 0,
    },
    {
      'question': 'Combien y a-t-il de jours dans une semaine ?',
      'answers': ['7', '6', '8', '5'],
      'correct': 0,
    },
    {
      'question': 'Quel métal est liquide à température ambiante ?',
      'answers': ['Mercure', 'Fer', 'Or', 'Cuivre'],
      'correct': 0,
    },
    {
      'question': 'Quelle est la plus grande île du monde ?',
      'answers': ['Groenland', 'Madagascar', 'Borneo', 'Nouvelle-Guinée'],
      'correct': 0,
    },
    {
      'question': 'Combien de lettres y a-t-il dans l\'alphabet français ?',
      'answers': ['26', '24', '25', '27'],
      'correct': 0,
    },
    {
      'question': 'Quel est le contraire de rapide ?',
      'answers': ['Lent', 'Vite', 'Fort', 'Grand'],
      'correct': 0,
    },
    {
      'question': 'Quelle est la forme de la Terre ?',
      'answers': ['Sphère', 'Cube', 'Cylindre', 'Triangle'],
      'correct': 0,
    },
  ];

  late List<Map<String, dynamic>> _gameQuestions;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeGame() {
    final random = Random();
    final shuffledQuestions = List<Map<String, dynamic>>.from(_questions)..shuffle(random);
    _gameQuestions = shuffledQuestions.take(_totalQuestions).toList();

    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _gameStarted = true;
      _answered = false;
      _selectedAnswer = null;
      _timeRemaining = 15;
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else {
        _onAnswerSelected(-1);
      }
    });
  }

  Future<void> _onAnswerSelected(int index) async {
    if (_answered) return;

    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedAnswer = index;
      _isCorrect = index == _gameQuestions[_currentQuestionIndex]['correct'];
      if (_isCorrect) {
        _score += 10 + (_timeRemaining * 2);
        _correctAnswers++;
      }
    });

    await Future.delayed(const Duration(seconds: 2));

    if (_currentQuestionIndex < _totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answered = false;
        _selectedAnswer = null;
        _timeRemaining = 15;
      });
      _startTimer();
    } else {
      _saveScore();
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
        'gameType': 'quiz',
        'score': _score,
        'correctAnswers': _correctAnswers,
        'totalQuestions': _totalQuestions,
        'playedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("[QuizGame] Erreur sauvegarde: $e");
    }
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
          'Quiz',
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
                : _currentQuestionIndex >= _totalQuestions
                    ? _buildEndScreen()
                    : _buildQuestionScreen(),
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
                colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.quiz,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Quiz Cognitif',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Répondez à $_totalQuestions questions\npour stimuler votre mémoire',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous avez 15 secondes par question',
            style: TextStyle(fontSize: 14, color: Colors.black38),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
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

  Widget _buildQuestionScreen() {
    final question = _gameQuestions[_currentQuestionIndex];

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
              _buildStat('Question', '${_currentQuestionIndex + 1}/$_totalQuestions', Icons.help_outline),
              _buildStat('Score', '$_score', Icons.star, const Color(0xFFFFD700)),
              _buildTimer(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Text(
              question['question'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: (question['answers'] as List).length,
            itemBuilder: (context, index) {
              return _buildAnswerButton(index, question['answers'][index], question['correct']);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? const Color(0xFF4A90E2), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E5AAC),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    final isLow = _timeRemaining <= 5;
    return Column(
      children: [
        Icon(
          Icons.timer,
          color: isLow ? Colors.red : const Color(0xFF4A90E2),
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          '$_timeRemaining s',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isLow ? Colors.red : const Color(0xFF2E5AAC),
          ),
        ),
        const Text(
          'Temps',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildAnswerButton(int index, String answer, int correctIndex) {
    Color backgroundColor = Colors.white;
    Color borderColor = const Color(0xFF4A90E2);
    Color textColor = const Color(0xFF2E5AAC);
    IconData? icon;

    if (_answered) {
      if (index == correctIndex) {
        backgroundColor = const Color(0xFF66BB6A);
        borderColor = const Color(0xFF66BB6A);
        textColor = Colors.white;
        icon = Icons.check_circle;
      } else if (index == _selectedAnswer) {
        backgroundColor = Colors.red.shade400;
        borderColor = Colors.red.shade400;
        textColor = Colors.white;
        icon = Icons.cancel;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _answered ? null : () => _onAnswerSelected(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _answered && index == correctIndex
                        ? Colors.white.withValues(alpha: 0.3)
                        : const Color(0xFF4A90E2).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _answered ? Colors.white : const Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    answer,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                if (icon != null)
                  Icon(icon, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndScreen() {
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
            child: Icon(
              _correctAnswers >= _totalQuestions ~/ 2 ? Icons.emoji_events : Icons.celebration,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _correctAnswers >= _totalQuestions ~/ 2 ? 'Bien joué !' : 'Continuez !',
            style: const TextStyle(
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
                _buildResultRow('Bonnes réponses', '$_correctAnswers/$_totalQuestions', Icons.check_circle, const Color(0xFF66BB6A)),
                const SizedBox(height: 16),
                _buildResultRow('Pourcentage', '${(_correctAnswers * 100 / _totalQuestions).toStringAsFixed(0)}%', Icons.percent, const Color(0xFF4A90E2)),
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
                    colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
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
