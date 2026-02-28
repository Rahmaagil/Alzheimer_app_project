import 'package:alzhecare/caregiver_map_tab.dart';
import 'package:alzhecare/caregiver_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDashboardTab extends StatefulWidget {
  const CaregiverDashboardTab({super.key});
  @override
  State<CaregiverDashboardTab> createState() => _CaregiverDashboardTabState();
}

class _CaregiverDashboardTabState extends State<CaregiverDashboardTab> {
  Map<String, dynamic>? _patientData;
  Map<String, dynamic>? _lastPosition;
  List<Map<String, dynamic>> _recentAlerts = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      String? patientUid = suiveurDoc.data()?['linkedPatient'];

      if (patientUid == null) {
        final p = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .limit(1).get();
        if (p.docs.isNotEmpty) patientUid = p.docs.first.id;
      }
      if (patientUid == null) { setState(() => _isLoading = false); return; }

      final patDoc = await FirebaseFirestore.instance
          .collection('users').doc(patientUid).get();
      _patientData = patDoc.data();
      _lastPosition = _patientData?['lastPosition'];

      final alertsSnap = await FirebaseFirestore.instance
          .collection('users').doc(patientUid)
          .collection('alerts').get();

      final list = alertsSnap.docs.map((d) {
        final data = d.data();
        return {
          'type': data['type'] ?? '',
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
        };
      }).toList();

      list.sort((a, b) {
        final ta = a['timestamp'] as Timestamp?;
        final tb = b['timestamp'] as Timestamp?;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      _recentAlerts = list;
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  bool get _isSafe {
    if (_recentAlerts.isEmpty) return true;
    final lastAlert = _recentAlerts.first;
    final type = lastAlert['type'] as String;
    final timestamp = lastAlert['timestamp'] as Timestamp?;

    if (timestamp == null) return true;

    final diff = DateTime.now().difference(timestamp.toDate());
    final isRecent = diff.inMinutes < 30;
    final isDangerous = (type == 'SOS' || type == 'perdu');

    return !(isRecent && isDangerous);
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'Inconnue';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Tableau de bord",
          style: TextStyle(color: Color(0xFF2E5AAC),
              fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          // Icône Settings uniquement
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF2E5AAC)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
              );
            },
            tooltip: 'Paramètres',
          ),
        ],
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
            ? const Center(child: CircularProgressIndicator(
            color: Color(0xFF4A90E2)))
            : RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // ── LOGO ──
              Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                    boxShadow: [BoxShadow(
                        color: Colors.blue.withOpacity(0.3), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.psychology,
                      color: Colors.white, size: 45)),

              const SizedBox(height: 20),

              Text(
                  _patientData?['name'] ?? 'Patient',
                  style: const TextStyle(fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC))),

              const SizedBox(height: 30),

              // ── STATUT ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: _isSafe
                      ? const LinearGradient(
                      colors: [Color(0xFF81C784), Color(0xFF66BB6A)])
                      : const LinearGradient(
                      colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(children: [
                  Icon(_isSafe ? Icons.check_circle : Icons.warning_rounded,
                      color: Colors.white, size: 50),
                  const SizedBox(height: 12),
                  Text(
                      _isSafe ? 'En Sécurité' : 'Alerte Active',
                      style: const TextStyle(fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                      _lastPosition != null
                          ? 'Position GPS disponible'
                          : 'Position inconnue',
                      style: const TextStyle(fontSize: 16,
                          color: Colors.white70)),
                ]),
              ),

              const SizedBox(height: 20),

              // ── DERNIÈRE POSITION ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.location_on,
                            color: Color(0xFF4A90E2), size: 22),
                        SizedBox(width: 8),
                        Text('Dernière position',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E5AAC))),
                      ]),
                      const SizedBox(height: 16),

                      if (_lastPosition == null)
                        const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Aucune position disponible',
                                style: TextStyle(fontSize: 16,
                                    color: Colors.black38))))
                      else ...[
                        Text(
                            'Lat: ${(_lastPosition!['latitude'] as num).toStringAsFixed(5)}'
                                '   Lng: ${(_lastPosition!['longitude'] as num).toStringAsFixed(5)}',
                            style: const TextStyle(fontSize: 15,
                                color: Colors.black54)),
                        const SizedBox(height: 8),
                        Text(_timeAgo(_lastPosition?['updatedAt']),
                            style: const TextStyle(fontSize: 15,
                                color: Colors.black45)),
                        const SizedBox(height: 16),

                        SizedBox(width: double.infinity, height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_)=>CaregiverMapTab()));
                              },
                              style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0),
                              child: Ink(
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        colors: [Color(0xFF7FB3FF),
                                          Color(0xFF2EC7F0)]),
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(30))),
                                child: const Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_rounded,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Text('Voir sur la carte',
                                          style: TextStyle(fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ]),
              ),

              const SizedBox(height: 20),

              // ── ALERTES RÉCENTES ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(children: [
                              Icon(Icons.notifications,
                                  color: Color(0xFFFFB74D), size: 22),
                              SizedBox(width: 8),
                              Text('Alertes récentes',
                                  style: TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E5AAC))),
                            ]),
                            if (_recentAlerts.isNotEmpty)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFF5F6D).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text('${_recentAlerts.length}',
                                      style: const TextStyle(fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF5F6D)))),
                          ]),
                      const SizedBox(height: 14),

                      if (_recentAlerts.isEmpty)
                        const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Aucune alerte ✓',
                                style: TextStyle(fontSize: 16,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w500))))
                      else
                        ..._recentAlerts.take(3).map((a) {
                          final type = a['type'] as String;
                          final isSOS = type == 'SOS';
                          final color = isSOS
                              ? const Color(0xFFFF5F6D)
                              : const Color(0xFFFFB74D);
                          final icon = isSOS
                              ? Icons.warning_rounded
                              : Icons.location_off;
                          final label = isSOS ? 'Alerte SOS'
                              : type == 'perdu' ? 'Sortie de zone' : type;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border(
                                    left: BorderSide(color: color, width: 4))),
                            child: Row(children: [
                              Icon(icon, color: color, size: 24),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E5AAC))),
                                    Text(_formatTime(a['timestamp']),
                                        style: const TextStyle(fontSize: 14,
                                            color: Colors.black45)),
                                  ])),
                            ]),
                          );
                        }),
                    ]),
              ),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}