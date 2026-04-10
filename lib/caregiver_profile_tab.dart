import 'package:alzhecare/fcm_service.dart';
import 'package:alzhecare/theme.dart';
import 'package:alzhecare/app_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_in_screen.dart';
import 'caregiver_settings_screen.dart';
import 'geofencing_service.dart';
import 'patient_caregiver_link_service.dart';
import 'caregiver_reminders_calendar_screen.dart';
import 'security_settings_screen.dart';
import 'caregiver_add_face_screen.dart';
import 'saved_faces_screen.dart';

class CaregiverProfileTab extends StatefulWidget {
  final String? selectedPatientUid;
  const CaregiverProfileTab({super.key, this.selectedPatientUid});

  @override
  State<CaregiverProfileTab> createState() => _CaregiverProfileTabState();
}

class _CaregiverProfileTabState extends State<CaregiverProfileTab> {
  Map<String, dynamic>? _patientData;
  List<String> _linkedPatientUids = [];
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
  String? _currentPatientUid;

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

      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedPatients = List<String>.from(
          suiveurDoc.data()?['linkedPatients'] ?? []
      );

      if (linkedPatients.isEmpty) {
        if (mounted) {
          AppNotifications.showWarning(context, "Aucun patient lié");
        }
        setState(() {
          _linkedPatientUids = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _linkedPatientUids = linkedPatients;
        _currentPatientUid = widget.selectedPatientUid ?? linkedPatients.first;
      });

      await _loadPatientData(widget.selectedPatientUid ?? linkedPatients.first);

    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPatientData(String patientUid) async {
    try {
      final patDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!patDoc.exists) {
        if (mounted) {
          AppNotifications.showError(context, "Patient introuvable");
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = patDoc.data();

      setState(() {
        _currentPatientUid = patientUid;
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final code = await PatientCaregiverLinkService.createInviteCode(
        caregiverUid: user.uid,
        expiryHours: 24,
      );

      if (mounted) Navigator.pop(context);

      if (code == null) {
        throw Exception('Erreur génération code');
      }

      _showCodeDialog(code);

    } catch (e) {
      if (mounted) Navigator.pop(context);

      AppNotifications.showError(context, "Erreur: $e");
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Code d\'invitation',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Partagez ce code avec votre proche',
              style: TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Expire dans 24h',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              AppNotifications.showSuccess(context, "Code copié");
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatientInfo() async {
    if (_currentPatientUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentPatientUid)
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
        AppNotifications.showSuccess(context, 'Profil mis à jour');
      }
    } catch (e) {
      if (mounted) {
        AppNotifications.showError(context, 'Erreur: $e');
      }
    }
  }

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ListView(
              controller: scrollController,
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

                _field(_nameCtrl, 'Nom du patient', Icons.person_outline),
                const SizedBox(height: 14),
                _field(_ageCtrl, 'Age', Icons.cake_outlined,
                    type: TextInputType.number),
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

                _field(_doctorCtrl, 'Medecin referent',
                    Icons.medical_services_outlined),
                const SizedBox(height: 14),
                _field(_treatmentCtrl, 'Traitement', Icons.medication_outlined),
                const SizedBox(height: 14),
                _field(_allergiesCtrl, 'Allergies', Icons.warning_amber_outlined),
                const SizedBox(height: 14),
                _field(_diabetesCtrl, 'Diabete', Icons.bloodtype_outlined),
                const SizedBox(height: 14),
                _field(_bloodPressureCtrl, 'Tension arterielle',
                    Icons.favorite_outline),
                const SizedBox(height: 14),
                _field(_otherConditionsCtrl, 'Autres conditions',
                    Icons.health_and_safety_outlined),
                const SizedBox(height: 14),
                _field(_homeAddressCtrl, 'Adresse du domicile',
                    Icons.home_outlined),
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

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
            ),
            child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FCMService.stopListeningFirestoreAlerts();
      await GeofencingService.stopTracking();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      print("[Logout] Erreur: $e");
    }
  }

  void _showRemindersManagement() {
    if (_currentPatientUid == null) {
      AppNotifications.showWarning(context, "Aucun patient lié");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaregiverRemindersCalendarScreen(patientUid: _currentPatientUid!),
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _generateInviteCode,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Générer un code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pour inviter un proche',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_patientData != null)
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

              _card(
                'Paramètres',
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CaregiverSettingsScreen(patientUid: _currentPatientUid)),
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
                                    'Zone de sécurité',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Domicile, rayon, notifications',
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
                    const Divider(height: 24),
                    InkWell(
                      onTap: _showRemindersManagement,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gérer les rappels',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ajouter, modifier, supprimer',
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
                    const Divider(height: 24),
                    InkWell(
                      onTap: () {
                        if (_currentPatientUid == null) {
                          AppNotifications.showWarning(context, "Aucun patient lié");
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SecuritySettingsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9575CD), Color(0xFF7E57C2)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.security, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sécurité',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Biométrie',
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
                    const Divider(height: 24),
                    InkWell(
                      onTap: () {
                        if (_currentPatientUid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Aucun patient lié"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CaregiverAddFaceScreen(
                              patientUid: _currentPatientUid!,
                              patientName: _patientData?['name'] ?? 'Patient',
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ajouter un proche',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Enregistrer un visage pour reconnaissance',
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
                    const Divider(height: 24),
                    InkWell(
                      onTap: () {
                        if (_currentPatientUid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Aucun patient lié"),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SavedFacesScreen(patientUid: _currentPatientUid),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.face, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Visages enregistrés',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Voir et gérer les proches reconnus',
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
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _logout,
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

// End of file