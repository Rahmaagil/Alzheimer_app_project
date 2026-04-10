import 'package:flutter/material.dart';
import 'app_security_service.dart';
import 'theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final biometricEnabled = await AppSecurityService.isBiometricEnabled();
    final biometricAvailable = await AppSecurityService.isBiometricAvailable();

    if (mounted) {
      setState(() {
        _biometricEnabled = biometricEnabled;
        _biometricAvailable = biometricAvailable;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final success = await AppSecurityService.enableBiometric(true);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'activer la biométrie'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await AppSecurityService.enableBiometric(false);
    }
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF4A90E2)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sécurité',
          style: TextStyle(
            color: Color(0xFF4A90E2),
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
                : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connexion biométrique',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _biometricAvailable
                      ? 'Utilisez votre empreinte digitale pour vous connecter rapidement'
                      : 'Votre appareil ne supporte pas la biométrie',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                if (_biometricAvailable) _buildBiometricCard(),
                const SizedBox(height: 24),
                _buildInfoCard(
                  icon: Icons.security,
                  title: 'Protection des données',
                  subtitle: 'Vos données sont chiffrées et stockées de manière sécurisée',
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.lock_outline,
                  title: 'Confidentialité',
                  subtitle: 'Vos données biométriques ne sont jamais partagées',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.fingerprint, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Empreinte digitale',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _biometricEnabled ? 'Activée' : 'Désactivée',
                  style: TextStyle(
                    fontSize: 13,
                    color: _biometricEnabled ? Colors.green : Colors.grey[600],
                    fontWeight: _biometricEnabled ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _biometricEnabled,
            onChanged: _toggleBiometric,
            activeColor: const Color(0xFF4A90E2),           // couleur du thumb
            activeTrackColor: const Color(0xFF4A90E2).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4A90E2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}