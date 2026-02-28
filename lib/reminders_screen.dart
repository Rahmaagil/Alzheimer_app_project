import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final List<Map<String, dynamic>> allItems = [];

      // Charger les médicaments
      final medsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medications')
          .get();

      for (var doc in medsSnapshot.docs) {
        final data = doc.data();
        final times = List<String>.from(data['times'] ?? []);

        // Créer une entrée par horaire
        for (var time in times) {
          final timeParts = time.split(':');
          final now = DateTime.now();
          final scheduledTime = DateTime(
            now.year,
            now.month,
            now.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );

          allItems.add({
            'id': doc.id,
            'type': 'medication',
            'title': data['name'] ?? 'Médicament',
            'subtitle': data['dosage'] ?? '',
            'date': Timestamp.fromDate(scheduledTime),
            'done': false, // TODO: Vérifier dans medication_logs
            'createdBy': 'patient',
          });
        }
      }

      // Charger les rendez-vous
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .orderBy('date')
          .get();

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        allItems.add({
          'id': doc.id,
          'type': 'appointment',
          'title': data['title'] ?? 'Rendez-vous',
          'subtitle': data['doctor'] != null && data['doctor'].isNotEmpty
              ? 'Dr. ${data['doctor']}'
              : data['location'] ?? '',
          'date': data['date'] as Timestamp?,
          'done': data['completed'] ?? false,
          'createdBy': 'patient',
          'appointmentType': data['type'] ?? 'medical',
        });
      }

      // Charger les anciens rappels simples (compatibilité)
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .orderBy('date')
          .get();

      for (var doc in remindersSnapshot.docs) {
        final data = doc.data();
        allItems.add({
          'id': doc.id,
          'type': 'reminder',
          'title': data['title'] ?? 'Rappel',
          'subtitle': '',
          'date': data['date'] as Timestamp?,
          'done': data['done'] ?? false,
          'createdBy': data['createdBy'] ?? 'patient',
        });
      }

      // Trier par date
      allItems.sort((a, b) {
        final dateA = a['date'] as Timestamp?;
        final dateB = b['date'] as Timestamp?;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      setState(() {
        _items = allItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur load data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDone(Map<String, dynamic> item) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final type = item['type'] as String;
      final docId = item['id'] as String;
      final currentDone = item['done'] as bool;

      String collection = 'reminders';
      String field = 'done';

      if (type == 'appointment') {
        collection = 'appointments';
        field = 'completed';
      } else if (type == 'medication') {
        // Pour les médicaments, on crée un log
        await _confirmMedication(item);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .doc(docId)
          .update({field: !currentDone});

      _loadData();
    } catch (e) {
      debugPrint("Erreur toggle: $e");
    }
  }

  Future<void> _confirmMedication(Map<String, dynamic> item) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Créer un log de prise
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medication_logs')
          .add({
        'medicationId': item['id'],
        'scheduledTime': item['date'],
        'takenAt': FieldValue.serverTimestamp(),
        'status': 'taken',
        'confirmedBy': 'patient',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Médicament confirmé"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _loadData();
    } catch (e) {
      debugPrint("Erreur confirm medication: $e");
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Supprimer ?"),
        content: Text("${item['title']} sera effacé."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final type = item['type'] as String;
      String collection = 'reminders';

      if (type == 'medication') {
        collection = 'medications';
      } else if (type == 'appointment') {
        collection = 'appointments';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .doc(item['id'] as String)
          .delete();

      _loadData();
    } catch (e) {
      debugPrint("Erreur delete: $e");
    }
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication, color: Colors.white),
              ),
              title: const Text(
                "Médicament",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Avec horaires de prise"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddMedicationDialog();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today, color: Color(0xFF10B981)),
              ),
              title: const Text(
                "Rendez-vous",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Médecin, analyses, hôpital"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddAppointmentDialog();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications, color: Color(0xFFFFB74D)),
              ),
              title: const Text(
                "Rappel simple",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Note rapide"),
              onTap: () {
                Navigator.pop(ctx);
                _showAddReminderDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    List<TimeOfDay> times = [TimeOfDay(hour: 8, minute: 0)];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF0F7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Text(
                "Nouveau médicament",
                style: TextStyle(color: Color(0xFF2E5AAC), fontSize: 22),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Nom du médicament",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dosageController,
                      decoration: InputDecoration(
                        labelText: "Dosage",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Horaires",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E5AAC),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF4A90E2)),
                          onPressed: () {
                            setDialogState(() {
                              times.add(TimeOfDay(hour: 12, minute: 0));
                            });
                          },
                        ),
                      ],
                    ),
                    ...times.asMap().entries.map((entry) {
                      final index = entry.key;
                      final time = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: time,
                                  );
                                  if (t != null) {
                                    setDialogState(() {
                                      times[index] = t;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF4A90E2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.access_time, color: Color(0xFF4A90E2)),
                                      const SizedBox(width: 8),
                                      Text(
                                        time.format(context),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E5AAC),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (times.length > 1) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    times.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler", style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final timeStrings = times.map((t) =>
                    "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}"
                    ).toList();

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('medications')
                        .add({
                      'name': name,
                      'dosage': dosageController.text.trim(),
                      'times': timeStrings,
                      'frequency': 'daily',
                      'startDate': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(dialogContext);
                    _loadData();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Médicament ajouté"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Ajouter",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddAppointmentDialog() {
    final titleController = TextEditingController();
    final doctorController = TextEditingController();
    final locationController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay(hour: 10, minute: 0);
    String appointmentType = 'medical';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF0F7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Text(
                "Nouveau rendez-vous",
                style: TextStyle(color: Color(0xFF2E5AAC), fontSize: 22),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Titre",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: doctorController,
                      decoration: InputDecoration(
                        labelText: "Médecin",
                        hintText: "Entrez le nom du médecin",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: "Lieu",
                        hintText: "Lieu du cabinet médical",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setDialogState(() => selectedDate = date);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A90E2)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.calendar_today, color: Color(0xFF4A90E2)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setDialogState(() => selectedTime = time);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A90E2)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.access_time, color: Color(0xFF4A90E2)),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'medical',
                          label: Text('Médecin'),
                          icon: Icon(Icons.local_hospital, size: 18),
                        ),
                        ButtonSegment(
                          value: 'analysis',
                          label: Text('Analyses'),
                          icon: Icon(Icons.science, size: 18),
                        ),
                        ButtonSegment(
                          value: 'hospital',
                          label: Text('Hôpital'),
                          icon: Icon(Icons.medical_services, size: 18),
                        ),
                      ],
                      selected: {appointmentType},
                      onSelectionChanged: (set) {
                        setDialogState(() {
                          appointmentType = set.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler", style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final appointmentDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('appointments')
                        .add({
                      'title': title,
                      'doctor': doctorController.text.trim(),
                      'location': locationController.text.trim(),
                      'date': Timestamp.fromDate(appointmentDateTime),
                      'type': appointmentType,
                      'completed': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(dialogContext);
                    _loadData();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Rendez-vous ajouté"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Ajouter",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddReminderDialog() {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF0F7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Text(
                "Nouveau rappel",
                style: TextStyle(color: Color(0xFF2E5AAC), fontSize: 22),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: "Que dois-je faire ?",
                      hintText: "Entrez votre rappel",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (t != null) {
                        setDialogState(() => selectedTime = t);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6EC6FF), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: Color(0xFF4A90E2), size: 32),
                          const SizedBox(width: 16),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E5AAC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler", style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    final now = DateTime.now();
                    final reminderDate = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('reminders')
                        .add({
                      'title': title,
                      'date': Timestamp.fromDate(reminderDate),
                      'createdBy': 'patient',
                      'done': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(dialogContext);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Ajouter",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((r) => !(r['done'] as bool)).toList();
    final done = _items.where((r) => r['done'] as bool).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Mes Rappels",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddMenu,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Ajouter",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : _items.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionHeader("À faire", const Color(0xFF2E5AAC)),
                ...pending.map((item) => _buildItemCard(item, false)),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildSectionHeader("Terminé", Colors.grey[700]!),
                ...done.map((item) => _buildItemCard(item, true)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isDone) {
    final type = item['type'] as String;
    final title = item['title'] as String;
    final subtitle = item['subtitle'] as String;
    final ts = item['date'] as Timestamp?;
    final timeText = ts != null ? _formatTime(ts) : '--:--';
    final dateText = ts != null ? _formatDate(ts) : '';

    IconData icon = Icons.notifications;
    Color color = const Color(0xFF4A90E2);

    if (type == 'medication') {
      icon = Icons.medication;
      color = const Color(0xFFFF6B6B);
    } else if (type == 'appointment') {
      icon = Icons.calendar_today;
      color = const Color(0xFF10B981);

      final appointmentType = item['appointmentType'] as String?;
      if (appointmentType == 'analysis') {
        icon = Icons.science;
      } else if (appointmentType == 'hospital') {
        icon = Icons.medical_services;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _toggleDone(item),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icône de type
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDone ? Colors.grey[300] : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isDone ? Colors.grey[600] : color,
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
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey[600] : const Color(0xFF1F2937),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          timeText,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        if (type == 'appointment' && dateText.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            dateText,
                            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  // Checkbox/Confirmer
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                      key: ValueKey(isDone),
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bouton supprimer
                  InkWell(
                    onTap: () => _delete(item),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 120, color: Colors.grey[300]),
          const SizedBox(height: 32),
          const Text(
            "Aucun rappel",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Ajoute des médicaments, rendez-vous\nou rappels pour ne rien oublier",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}