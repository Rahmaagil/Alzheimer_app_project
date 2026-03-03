import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'caregiver_settings_screen.dart';

class CaregiverProfileTab extends StatefulWidget {
  const CaregiverProfileTab({super.key});
  @override
  State<CaregiverProfileTab> createState() => _CaregiverProfileTabState();
}

class _CaregiverProfileTabState extends State<CaregiverProfileTab> {
  Map<String, dynamic>? _patientData;
  String? _patientUid;
  bool _isLoading = true;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _treatmentCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _homeAddressCtrl = TextEditingController();
  final _diabetesCtrl = TextEditingController();
  final _bloodPressureCtrl = TextEditingController();
  final _otherConditionsCtrl = TextEditingController();

  String _diseaseStage = 'Léger';
  final List<String> _stages = ['Léger', 'Modéré', 'Avancé'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _doctorCtrl.dispose();
    _treatmentCtrl.dispose();
    _allergiesCtrl.dispose();
    _homeAddressCtrl.dispose();
    _diabetesCtrl.dispose();
    _bloodPressureCtrl.dispose();
    _otherConditionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer le document du suiveur
      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Récupérer l'UID du patient lié
      final patientUid = suiveurDoc.data()?['linkedPatient'] as String?;

      if (patientUid == null) {
        // Pas de patient lié
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aucun patient lié à ce compte"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      _patientUid = patientUid;

      // Charger les données du patient lié
      final patDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!patDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Patient introuvable"),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = patDoc.data();

      setState(() {
        _patientData = data;
        _nameCtrl.text = data?['name'] ?? '';
        _ageCtrl.text = data?['age']?.toString() ?? '';
        _doctorCtrl.text = data?['doctor'] ?? '';
        _treatmentCtrl.text = data?['treatment'] ?? '';
        _allergiesCtrl.text = data?['allergies'] ?? '';
        _homeAddressCtrl.text = data?['homeAddress'] ?? '';
        _diabetesCtrl.text = data?['diabetes'] ?? '';
        _bloodPressureCtrl.text = data?['bloodPressure'] ?? '';
        _otherConditionsCtrl.text = data?['otherConditions'] ?? '';
        _diseaseStage = data?['diseaseStage'] ?? 'Léger';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePatientInfo() async {
    if (_patientUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_patientUid)
          .update({
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'doctor': _doctorCtrl.text.trim(),
        'treatment': _treatmentCtrl.text.trim(),
        'allergies': _allergiesCtrl.text.trim(),
        'homeAddress': _homeAddressCtrl.text.trim(),
        'diabetes': _diabetesCtrl.text.trim(),
        'bloodPressure': _bloodPressureCtrl.text.trim(),
        'otherConditions': _otherConditionsCtrl.text.trim(),
        'diseaseStage': _diseaseStage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Modifier les informations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5AAC),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Informations générales
                  _field(_nameCtrl, 'Nom du patient', Icons.person_outline),
                  const SizedBox(height: 14),
                  _field(_ageCtrl, 'Âge', Icons.cake_outlined, type: TextInputType.number),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _diseaseStage,
                    items: _stages
                        .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 16)),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => _diseaseStage = v);
                    },
                    decoration: InputDecoration(
                      labelText: 'Stade de la maladie',
                      labelStyle: const TextStyle(fontSize: 16),
                      prefixIcon: const Icon(
                        Icons.medical_information_outlined,
                        color: Color(0xFF4A90E2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _field(_doctorCtrl, 'Médecin référent', Icons.medical_services_outlined),
                  const SizedBox(height: 14),
                  _field(_treatmentCtrl, 'Traitement', Icons.medication_outlined),
                  const SizedBox(height: 14),
                  _field(_allergiesCtrl, 'Allergies', Icons.warning_amber_outlined),
                  const SizedBox(height: 14),

                  // Nouvelles conditions médicales
                  _field(_diabetesCtrl, 'Diabète', Icons.bloodtype_outlined),
                  const SizedBox(height: 14),
                  _field(_bloodPressureCtrl, 'Tension artérielle', Icons.favorite_outline),
                  const SizedBox(height: 14),
                  _field(_otherConditionsCtrl, 'Autres conditions', Icons.health_and_safety_outlined),
                  const SizedBox(height: 14),

                  _field(_homeAddressCtrl, 'Adresse du domicile', Icons.home_outlined),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _savePatientInfo();
                      },
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
                            'Enregistrer',
                            style: TextStyle(
                              fontSize: 17,
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
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType? type,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 16),
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // AVATAR
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 45),
              ),

              const SizedBox(height: 16),

              Text(
                _patientData?['name'] ?? 'Patient',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),

              const SizedBox(height: 30),

              // INFOS PATIENT
              _card(
                'Informations du patient',
                action: _buildGradientButton('Modifier', _showEditDialog),
                child: Column(
                  children: [
                    if ((_patientData?['age'] ?? 0) > 0)
                      _infoRow(Icons.cake_outlined, 'Âge', '${_patientData!['age']} ans'),
                    if ((_patientData?['diseaseStage'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.medical_information_outlined, 'Stade', _patientData!['diseaseStage']),
                    ],
                    if ((_patientData?['doctor'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.medical_services_outlined, 'Médecin', _patientData!['doctor']),
                    ],
                    if ((_patientData?['treatment'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.medication_outlined, 'Traitement', _patientData!['treatment']),
                    ],
                    if ((_patientData?['allergies'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.warning_amber_outlined, 'Allergies', _patientData!['allergies']),
                    ],
                    if ((_patientData?['diabetes'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.bloodtype_outlined, 'Diabète', _patientData!['diabetes']),
                    ],
                    if ((_patientData?['bloodPressure'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.favorite_outline, 'Tension', _patientData!['bloodPressure']),
                    ],
                    if ((_patientData?['otherConditions'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.health_and_safety_outlined, 'Autres', _patientData!['otherConditions']),
                    ],
                    if ((_patientData?['homeAddress'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _infoRow(Icons.home_outlined, 'Domicile', _patientData!['homeAddress']),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // PARAMÈTRES
              _card(
                'Paramètres',
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configurer la zone de sécurité',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E5AAC),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Domicile, rayon de zone, notifications',
                                style: TextStyle(fontSize: 14, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 18),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // DÉCONNEXION
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5F6D),
                    side: const BorderSide(color: Color(0xFFFF5F6D), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 22),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, {required Widget child, Widget? action}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, color: const Color(0xFF4A90E2), size: 18),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(fontSize: 15, color: Colors.black45)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2E5AAC),
          ),
        ),
      ),
    ],
  );

  Widget _buildGradientButton(String text, VoidCallback onPressed) => SizedBox(
    height: 36,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}