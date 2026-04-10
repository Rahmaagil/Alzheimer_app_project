import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class UrgentCallScreen extends StatefulWidget {
  const UrgentCallScreen({super.key});

  @override
  State<UrgentCallScreen> createState() => _UrgentCallScreenState();
}

class _UrgentCallScreenState extends State<UrgentCallScreen> {
  List<Map<String, dynamic>> _caregivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCaregivers();
  }

  Future<void> _loadCaregivers() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedCaregivers = List<String>.from(
        userDoc.data()?['linkedCaregivers'] ?? []
      );

      final caregiversList = <Map<String, dynamic>>[];

      for (final caregiverId in linkedCaregivers) {
        final caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .get();

        if (caregiverDoc.exists) {
          final data = caregiverDoc.data();
          final phone = data?['phone'] as String?;

          if (phone != null && phone.isNotEmpty) {
            caregiversList.add({
              'id': caregiverId,
              'name': data?['name'] ?? 'Suiveur',
              'phone': phone,
            });
          }
        }
      }

      setState(() {
        _caregivers = caregiversList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("[UrgentCall] Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _callCaregiver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible de passer l'appel"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          'Appel urgent',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
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
                : _caregivers.isEmpty
                    ? _buildEmptyState()
                    : _buildCaregiversList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5F6D).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.phone_disabled,
                size: 60,
                color: Color(0xFFFF5F6D),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun suiveur trouvé',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Contactez un proche pour qu\'il\npuisse vous aider en cas d\'urgence',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiversList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5F6D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF5F6D), width: 2),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFFF5F6D), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Appuyez sur un contact pour\nl\'appeler directement',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF5F6D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Vos suiveurs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 16),
          ..._caregivers.map((caregiver) => _buildCaregiverCard(caregiver)),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(Map<String, dynamic> caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _callCaregiver(caregiver['phone']),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.phone, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiver['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E5AAC),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            caregiver['phone'],
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call,
                    color: Color(0xFF66BB6A),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
