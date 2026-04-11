import 'package:flutter/material.dart';
import 'theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'fcm_service.dart';

class CaregiverRemindersCalendarScreen extends StatefulWidget {
  final String patientUid;
  const CaregiverRemindersCalendarScreen({super.key, required this.patientUid});

  @override
  State<CaregiverRemindersCalendarScreen> createState() => _CaregiverRemindersCalendarScreenState();
}

class _CaregiverRemindersCalendarScreenState extends State<CaregiverRemindersCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _allReminders = [];
  bool _isLoading = true;
  String _patientName = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .get();

      _patientName = patientDoc.data()?['name'] ?? 'Patient';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('reminders')
          .orderBy('date', descending: false)
          .get();

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'date': data['date'] as Timestamp?,
          'done': data['done'] ?? false,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allReminders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement rappels: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getRemindersForDay(DateTime day) {
    return _allReminders.where((reminder) {
      final date = reminder['date'] as Timestamp?;
      if (date == null) return false;
      final reminderDate = date.toDate();
      return reminderDate.year == day.year &&
          reminderDate.month == day.month &&
          reminderDate.day == day.day;
    }).toList();
  }

  Future<void> _addReminder() async {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = _selectedDay ?? DateTime.now();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF0F7FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Nouveau rappel pour $_patientName',
                style: const TextStyle(
                  color: Color(0xFF2E5AAC),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Quoi ? (médicament, rendez-vous...)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF4A90E2), size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF4A90E2), size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  selectedTime.format(context),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler"),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Veuillez entrer un titre")),
                        );
                        return;
                      }

                      final reminderDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      try {
                        final docRef = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.patientUid)
                            .collection('reminders')
                            .add({
                          'title': title,
                          'date': Timestamp.fromDate(reminderDateTime),
                          'done': false,
                          'createdAt': FieldValue.serverTimestamp(),
                          'createdBy': 'caregiver',
                        });

                        await FCMService.sendReminderToCaregiver(
                          patientUid: widget.patientUid,
                          reminderTitle: title,
                          scheduledTime: reminderDateTime,
                        );

                        if (mounted) Navigator.pop(dialogContext);

                        await Future.delayed(const Duration(milliseconds: 300));
                        await _loadData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text("Rappel ajouté pour $_patientName"),
                                ],
                              ),
                              backgroundColor: const Color(0xFF66BB6A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Erreur : $e"),
                              backgroundColor: const Color(0xFFFF5F6D),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text("Ajouter", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReminder(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer ce rappel ?"),
        content: const Text("Cette action est irréversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('reminders')
          .doc(docId)
          .delete();

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rappel supprimé"), backgroundColor: Color(0xFF66BB6A)),
        );
      }
    } catch (e) {
      debugPrint("Erreur suppression: $e");
    }
  }

  Future<void> _toggleDone(String docId, bool currentDone) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('reminders')
          .doc(docId)
          .update({'done': !currentDone});

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentDone ? "Rappel marqué comme fait ✅" : "Rappel marqué comme non fait"),
            backgroundColor: const Color(0xFF66BB6A),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur toggle: $e");
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final selectedReminders = _getRemindersForDay(_selectedDay ?? DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Rappels de $_patientName",
          style: const TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF2E5AAC)),
            onPressed: _addReminder,
          ),
        ],
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
                : Column(
              children: [
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonDecoration: BoxDecoration(
                      color: Color(0xFF4A90E2),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: selectedReminders.isEmpty
                      ? const Center(
                    child: Text(
                      'Aucun rappel pour cette journée',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = selectedReminders[index];
                      final docId = reminder['id'] as String;
                      final title = reminder['title'] as String;
                      final done = reminder['done'] as bool;
                      final timeText = _formatTime(reminder['date'] as Timestamp?);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Checkbox(
                            value: done,
                            onChanged: (_) => _toggleDone(docId, done),
                            activeColor: const Color(0xFF66BB6A),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: done ? Colors.grey : const Color(0xFF2E5AAC),
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(timeText, style: TextStyle(color: Colors.grey[600])),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5F6D)),
                            onPressed: () => _deleteReminder(docId),
                          ),
                        ),
                      );
                    },
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