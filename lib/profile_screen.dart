import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _caregiverPhoneController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _doctorController = TextEditingController();

  String _diseaseStage = "Léger";
  bool _isLoading = true;

  final List<String> _stages = [
    "Léger",
    "Modéré",
    "Avancé",
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ───────────── LOAD DATA ─────────────
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data();

      _nameController.text = data?['name'] ?? '';
      _phoneController.text = data?['phone'] ?? '';
      _caregiverPhoneController.text = data?['caregiverPhone'] ?? '';
      _homeAddressController.text = data?['homeAddress'] ?? ''; // Charger l'adresse domicile
      _treatmentController.text = data?['treatment'] ?? '';
      _allergiesController.text = data?['allergies'] ?? '';
      _doctorController.text = data?['doctor'] ?? '';
      _diseaseStage = data?['diseaseStage'] ?? "Léger";
    }

    setState(() => _isLoading = false);
  }

  // ───────────── SAVE DATA ─────────────
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'caregiverPhone': _caregiverPhoneController.text.trim(),
      'homeAddress': _homeAddressController.text.trim(), // Sauvegarder l'adresse domicile
      'treatment': _treatmentController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'doctor': _doctorController.text.trim(),
      'diseaseStage': _diseaseStage,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profil mis à jour avec succès !")),
    );
  }

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Mon Profil",
          style: TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold, fontSize: 24),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── SECTION PERSONNELLE ──
                _buildSectionHeader("Informations personnelles", Icons.person),
                const SizedBox(height: 15),
                _buildTextField(_nameController, "Votre nom complet", Icons.account_circle),
                const SizedBox(height: 15),
                _buildTextField(null, "Votre email", Icons.email, enabled: false, hint: user?.email ?? "Non disponible"),
                const SizedBox(height: 15),
                _buildTextField(_phoneController, "Votre téléphone", Icons.phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 15),
                _buildTextField(_caregiverPhoneController, "Téléphone de votre proche", Icons.phone_android, keyboardType: TextInputType.phone),
                const SizedBox(height: 15),
                _buildTextField(_homeAddressController, "Adresse de votre domicile", Icons.home, maxLines: 2),

                const SizedBox(height: 30),
                const Divider(color: Color(0xFF2E5AAC), thickness: 1),

                // ── SECTION MÉDICALE ──
                const SizedBox(height: 20),
                _buildSectionHeader("Informations médicales", Icons.local_hospital),
                const SizedBox(height: 15),
                _buildDropdownField(),
                const SizedBox(height: 15),
                _buildTextField(_treatmentController, "Votre traitement", Icons.medical_services),
                const SizedBox(height: 15),
                _buildTextField(_allergiesController, "Vos allergies", Icons.warning),
                const SizedBox(height: 15),
                _buildTextField(_doctorController, "Votre médecin référent", Icons.person_search),

                const SizedBox(height: 40),

                // ── BOUTON SAUVEGARDER ──
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                      child: const Center(
                        child: Text(
                          "Enregistrer les modifications",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E5AAC), size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E5AAC),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController? controller, String label, IconData icon, {bool enabled = true, TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? hint}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6EC6FF), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6EC6FF), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: _diseaseStage,
      items: _stages.map((stage) {
        return DropdownMenuItem(
          value: stage,
          child: Text(stage, style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _diseaseStage = value!;
        });
      },
      decoration: InputDecoration(
        labelText: "Stade de la maladie",
        prefixIcon: const Icon(Icons.accessibility, color: Color(0xFF4A90E2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6EC6FF), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6EC6FF), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}