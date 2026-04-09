import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme.dart';
import 'background_service.dart';
import 'caregiver_alerts_screen.dart';
import 'caregiver_dashboard_tab.dart';
import 'caregiver_map_tab.dart';
import 'caregiver_profile_tab.dart';
import 'caregiver_chatbot_screen.dart';
import 'fcm_service.dart';
import 'direct_chat_screen.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  int _currentIndex = 0;
  int _pendingAlerts = 0;
  
  List<Map<String, dynamic>> _patientsList = [];
  String? _selectedPatientId;
  bool _isLoadingPatients = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _listenAlerts();
    _initializeFCM();
  }

  Future<void> _loadPatients() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedPatients = List<String>.from(
          suiveurDoc.data()?['linkedPatients'] ?? []
      );

      if (linkedPatients.isEmpty) {
        setState(() {
          _patientsList = [];
          _isLoadingPatients = false;
        });
        return;
      }

      final patientsData = <Map<String, dynamic>>[];
      for (final patientId in linkedPatients) {
        final patientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
        
        if (patientDoc.exists) {
          patientsData.add({
            'id': patientId,
            'name': patientDoc.data()?['name'] ?? 'Patient',
          });
        }
      }

      setState(() {
        _patientsList = patientsData;
        _selectedPatientId = patientsData.isNotEmpty ? patientsData.first['id'] : null;
        _isLoadingPatients = false;
      });
    } catch (e) {
      debugPrint("[CaregiverHome] Erreur chargement patients: $e");
      setState(() => _isLoadingPatients = false);
    }
  }

  Future<void> _initializeFCM() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FCMService.startListeningFirestoreAlerts(user.uid);
      print("[CaregiverHome] FCM listener demarre");
    }
  }

  Future<void> _listenAlerts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // MODIFIE: Utiliser linkedPatients[] au lieu de linkedPatient
      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();

      final linkedPatients = List<String>.from(
          suiveurDoc.data()?['linkedPatients'] ?? []
      );

      if (linkedPatients.isEmpty) {
        if (mounted) setState(() => _pendingAlerts = 0);
        return;
      }

      // Ecouter notifications pour ce suiveur
      FirebaseFirestore.instance
          .collection('notifications')
          .where('caregiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() => _pendingAlerts = snap.docs.length);
      });
    } catch (e) {
      debugPrint('[CaregiverHome] Erreur listen alerts: $e');
    }
  }

  void _onTabChanged(int index) {
    // Quand on clique sur l'onglet des alertes (index 2), marquer les alertes comme vues
    if (index == 2 && _pendingAlerts > 0) {
      _markAlertsAsSeen();
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _markAlertsAsSeen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pendingQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('caregiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingQuery.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in pendingQuery.docs) {
        batch.update(doc.reference, {
          'status': 'seen',
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      
      setState(() => _pendingAlerts = 0);
      print("[CaregiverHome] Alertes marquées comme vues");
    } catch (e) {
      print("[CaregiverHome] Erreur lors du marquage des alertes: $e");
    }
  }

  Future<void> _showChatOptions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final linkedPatients = List<String>.from(
        userDoc.data()?['linkedPatients'] ?? []
    );

    if (linkedPatients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun patient lié'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Communication',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF6EC6FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: Colors.white),
              ),
              title: const Text(
                'Assistant virtuel',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
              subtitle: const Text('Chatbot AI pour questions'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CaregiverChatbotScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: linkedPatients.length,
                itemBuilder: (context, index) {
                  final patientId = linkedPatients[index];
                  return FutureBuilder(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(patientId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFF81C784),
                          ),
                          title: Text('Chargement...'),
                        );
                      }
                      final name = snapshot.data?['name'] ?? 'Patient';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF81C784),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E5AAC),
                        )),
                        subtitle: const Text('Patient'),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF81C784),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                otherUserId: patientId,
                                otherUserName: name,
                                isCaregiver: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientDropdown() {
    if (_isLoadingPatients) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90E2)),
      );
    }

    if (_patientsList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A90E2).withValues(alpha: 0.3)),
      ),
      child: DropdownButton<String>(
        value: _selectedPatientId,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2E5AAC)),
        underline: const SizedBox(),
        style: const TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold),
        items: _patientsList.map((patient) {
          return DropdownMenuItem(
            value: patient['id'] as String,
            child: Text(
              patient['name'] as String,
              style: const TextStyle(color: Color(0xFF2E5AAC)),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPatientId = value);
          }
        },
      ),
    );
  }

  List<Widget> get _tabs {
    if (_selectedPatientId == null) {
      return [
        const CaregiverDashboardTab(),
        const CaregiverMapTab(),
        const CaregiverAlertsTab(),
        const CaregiverProfileTab(),
      ];
    }
    
    return [
      CaregiverDashboardTab(patientUid: _selectedPatientId ?? ''),
      CaregiverMapTab(patientUid: _selectedPatientId ?? ''),
      CaregiverAlertsTab(patientUids: _selectedPatientId != null ? [_selectedPatientId!] : []),
      CaregiverProfileTab(selectedPatientUid: _selectedPatientId),
    ];
  }

  @override
  void dispose() {
    FCMService.stopListeningFirestoreAlerts();
    BackgroundService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'AlzheCare',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          _buildPatientDropdown(),
        ],
        iconTheme: const IconThemeData(color: Color(0xFF2E5AAC)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),

      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6EC6FF), Color(0xFF2EC7F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showChatOptions(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.psychology,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20, 
              offset: const Offset(0, -3)
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(children: [
              _navItem(0, Icons.dashboard_rounded, 'Tableau de bord'),
              _navItem(1, Icons.map_rounded, 'Carte'),
              _navItemBadge(2, Icons.notifications_rounded, 'Alertes'),
              _navItem(3, Icons.person_rounded, 'Profil'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final sel = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: sel 
                ? const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: sel ? [
              BoxShadow(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: sel ? Colors.white : Colors.grey[400], size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : Colors.grey[400])),
          ]),
        ),
      ),
    );
  }

  Widget _navItemBadge(int idx, IconData icon, String label) {
    final sel = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: sel 
                ? const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: sel ? [
              BoxShadow(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(children: [
              Icon(icon,
                  color: sel ? Colors.white : Colors.grey[400], size: 26),
              if (_pendingAlerts > 0)
                Positioned(right: -2, top: -2,
                    child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF5F6D), 
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5F6D).withValues(alpha: 0.4),
                                blurRadius: 6,
                              )
                            ]
                        ),
                        child: Center(child: Text('$_pendingAlerts',
                            style: const TextStyle(color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.bold))))),
            ]),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : Colors.grey[400])),
          ]),
        ),
      ),
    );
  }
}