import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_caregiver_link_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _profileData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Mes Informations",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 24,
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
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Photo de profil
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nom
                  Text(
                    _profileData?['name'] ?? "Mon nom",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Section: Qui suis-je ?
                  _buildSectionTitle("Qui suis-je ?"),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    icon: Icons.person,
                    label: "Mon nom",
                    value: _profileData?['name'] ?? "Non renseigné",
                    color: const Color(0xFF4A90E2),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.cake,
                    label: "Mon âge",
                    value: _profileData?['age'] != null
                        ? "${_profileData!['age']} ans"
                        : "Non renseigné",
                    color: const Color(0xFF10B981),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.home,
                    label: "Mon domicile",
                    value: _profileData?['homeAddress'] ?? "Non renseigné",
                    color: const Color(0xFFFFB74D),
                  ),

                  const SizedBox(height: 40),

                  // Section: Mes contacts
                  _buildSectionTitle("Mes contacts"),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    icon: Icons.phone,
                    label: "Mon proche",
                    value: _profileData?['caregiverPhone'] ?? "Non renseigné",
                    color: const Color(0xFF10B981),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.medical_services,
                    label: "Mon médecin",
                    value: _profileData?['doctor'] ?? "Non renseigné",
                    color: const Color(0xFF4A90E2),
                  ),

                  const SizedBox(height: 40),

                  // Section: Ma santé
                  _buildSectionTitle("Ma santé"),
                  const SizedBox(height: 16),

                  _buildInfoCard(
                    icon: Icons.warning,
                    label: "Mes allergies",
                    value: (_profileData?['allergies'] != null &&
                        _profileData!['allergies'].toString().isNotEmpty)
                        ? _profileData!['allergies']
                        : "Aucune allergie",
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  _buildInfoCard(
                    icon: Icons.medication,
                    label: "Mon traitement",
                    value: (_profileData?['treatment'] != null &&
                        _profileData!['treatment'].toString().isNotEmpty)
                        ? _profileData!['treatment']
                        : "Aucun traitement",
                    color: const Color(0xFFFF6B6B),
                  ),

                  if (_profileData?['diabetes'] != null &&
                      _profileData!['diabetes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.bloodtype,
                      label: "Diabète",
                      value: _profileData!['diabetes'],
                      color: const Color(0xFF9C27B0),
                    ),
                  ],

                  if (_profileData?['bloodPressure'] != null &&
                      _profileData!['bloodPressure'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.favorite,
                      label: "Ma tension",
                      value: _profileData!['bloodPressure'],
                      color: const Color(0xFFE91E63),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Note pour le patient
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF4A90E2),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            "Votre proche peut modifier ces informations si nécessaire",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E5AAC),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Contenu
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}