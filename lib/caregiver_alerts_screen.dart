import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverAlertsTab extends StatefulWidget {
  const CaregiverAlertsTab({super.key});

  @override
  State<CaregiverAlertsTab> createState() => _CaregiverAlertsTabState();
}

class _CaregiverAlertsTabState extends State<CaregiverAlertsTab> {
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? patientUid = doc.data()?['linkedPatient'];

      if (patientUid == null) {
        final p = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .limit(1)
            .get();
        if (p.docs.isNotEmpty) patientUid = p.docs.first.id;
      }

      if (patientUid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .collection('alerts')
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'type': data['type'] ?? '',
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
          'latitude': data['latitude'],
          'longitude': data['longitude'],
        };
      }).toList();

      list.sort((a, b) {
        final ta = a['timestamp'] as Timestamp?;
        final tb = b['timestamp'] as Timestamp?;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      setState(() {
        _alerts = list;
        _filtered = list;
        _isLoading = false;
      });

      // Automatically mark pending alerts as seen when tab is loaded
      if (list.any((a) => a['status'] == 'pending')) {
        _markAllAlertsAsSeen();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading alerts: $e');
    }
  }

  Future<void> _markAllAlertsAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final caregiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String? patientUid = caregiverDoc.data()?['linkedPatient'];

    if (patientUid == null) {
      final p = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .limit(1)
          .get();
      if (p.docs.isNotEmpty) patientUid = p.docs.first.id;
    }

    if (patientUid == null) return;

    final pendingQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(patientUid)
        .collection('alerts')
        .where('status', isEqualTo: 'pending');

    final snapshot = await pendingQuery.get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'seen',
        'seenAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Update local state so UI reflects change immediately (optional but nice)
    setState(() {
      for (var alert in _alerts) {
        if (alert['status'] == 'pending') {
          alert['status'] = 'seen';
        }
      }
      _filtered = List.from(_alerts);
    });
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _alerts
          : _alerts
          .where((a) => a['type']
          .toString()
          .toLowerCase()
          .contains(q.toLowerCase()))
          .toList();
    });
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '--';
    final d = ts.toDate();
    final now = DateTime.now();
    final t = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.day == now.day && d.month == now.month) return 'Aujourd\'hui à $t';
    if (d.day == now.day - 1) return 'Hier à $t';
    return '${d.day}/${d.month} à $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          'Alertes',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une alerte...',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2), size: 24),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} alertes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
                  : _filtered.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.black26),
                    SizedBox(height: 16),
                    Text('Aucune alerte', style: TextStyle(fontSize: 18, color: Colors.black38)),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadAlerts,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _buildCard(_filtered[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> alert) {
    final type = alert['type'] as String;
    final hasPos = alert['latitude'] != null;
    final isSOS = type == 'SOS';
    final color = isSOS
        ? const Color(0xFFFF5F6D)
        : type == 'perdu'
        ? const Color(0xFFFFB74D)
        : const Color(0xFF4A90E2);
    final icon = isSOS ? Icons.warning_rounded : Icons.location_off;
    final label = isSOS ? 'Alerte SOS' : type == 'perdu' ? 'Sortie de zone' : type;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(alert['timestamp']),
                    style: const TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                ],
              ),
            ),
            if (hasPos)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                ),
                child: const Icon(Icons.map, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}