import 'package:flutter/material.dart';
import 'fall_detection_background_service.dart';

class PatientFallMonitorScreen extends StatefulWidget {
  const PatientFallMonitorScreen({Key? key}) : super(key: key);

  @override
  State<PatientFallMonitorScreen> createState() => _PatientFallMonitorScreenState();
}

class _PatientFallMonitorScreenState extends State<PatientFallMonitorScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isMonitoring => FallDetectionBackgroundService.isRunning;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFEAF2FF),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Détection de Chute',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatusIcon(isActive: _isMonitoring),
                          const SizedBox(height: 24),
                          Text(
                            _isMonitoring
                                ? 'Surveillance Active'
                                : 'Service Inactif',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E5AAC),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isMonitoring 
                                  ? const Color(0xFF66BB6A).withValues(alpha: 0.1)
                                  : const Color(0xFFFF9800).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isMonitoring 
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFFF9800),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isMonitoring ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: _isMonitoring ? const Color(0xFF66BB6A) : const Color(0xFFFF9800),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isMonitoring ? 'Vous êtes protégé(e)' : 'Service non démarré',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _isMonitoring ? const Color(0xFF66BB6A) : const Color(0xFFFF9800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
                                    SizedBox(width: 12),
                                    Text(
                                      'Comment ça fonctionne ?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E5AAC),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '• Surveillance continue en arrière-plan\n'
                                  '• En cas de chute : 30 secondes pour répondre\n'
                                  '• Bouton "Je vais bien" annule l\'alerte\n'
                                  '• Pas de réponse → alerte automatique',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700]!,
                                    height: 1.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.layers, color: Color(0xFF4A90E2), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Actif en arrière-plan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF4A90E2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
}

class _StatusIcon extends StatefulWidget {
  final bool isActive;
  const _StatusIcon({required this.isActive});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.isActive ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: widget.isActive
                ? [const Color(0xFF6EC6FF), const Color(0xFF4A90E2)]
                : [Colors.grey[400]!, Colors.grey[600]!],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isActive
                  ? const Color(0xFF4A90E2).withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          widget.isActive ? Icons.sensors : Icons.sensors_off,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }
}