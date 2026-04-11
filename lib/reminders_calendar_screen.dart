import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'fcm_service.dart';
import 'add_reminder_screen.dart';

class RemindersCalendarScreen extends StatefulWidget {
  const RemindersCalendarScreen({super.key});

  @override
  State<RemindersCalendarScreen> createState() => _RemindersCalendarScreenState();
}

class _RemindersCalendarScreenState extends State<RemindersCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _allReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
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

      setState(() {
        _allReminders = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getRemindersForDay(DateTime day) {
    return _allReminders.where((reminder) {
      final date = reminder['date'];
      if (date == null) return false;
      final reminderDate = date.toDate();
      return reminderDate.year == day.year &&
          reminderDate.month == day.month &&
          reminderDate.day == day.day;
    }).toList();
  }

  Future<void> _addReminder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddReminderScreen()),
    );
    _loadReminders();
  }

  Future<void> _toggleDone(String docId, bool currentDone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(docId)
          .update({'done': !currentDone});

      _loadReminders();
    } catch (e) {
      debugPrint("Erreur: $e");
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
        title: const Text(
          "Calendrier des rappels",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF2E5AAC)),
            onPressed: _addReminder,
          ),
        ],
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
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
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
                    onFormatChanged: (format) {
                      setState(() => _calendarFormat = format);
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: _getRemindersForDay,
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: const TextStyle(color: Color(0xFF2E5AAC)),
                      defaultTextStyle: const TextStyle(color: Color(0xFF2E5AAC)),
                      selectedDecoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: const Color(0xFF6EC6FF).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: Color(0xFFFF9800),
                        shape: BoxShape.circle,
                      ),
                      markersMaxCount: 3,
                      markerSize: 6,
                      markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: Color(0xFF2E5AAC),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF2E5AAC)),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF2E5AAC)),
                      formatButtonTextStyle: TextStyle(color: Color(0xFF4A90E2)),
                      formatButtonDecoration: BoxDecoration(
                        border: Border.fromBorderSide(BorderSide(color: Color(0xFF4A90E2))),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold),
                      weekendStyle: TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt, color: Color(0xFF2E5AAC)),
                        const SizedBox(width: 8),
                        Text(
                          "Rappels du ${_selectedDay?.day ?? ''}/${_selectedDay?.month ?? ''}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E5AAC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: selectedReminders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Aucun rappel ce jour",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: selectedReminders.length,
                            itemBuilder: (context, index) {
                              final reminder = selectedReminders[index];
                              final title = reminder['title'] as String;
                              final ts = reminder['date'] as Timestamp?;
                              final docId = reminder['id'] as String;
                              final isDone = reminder['done'] as bool;
                              final timeText = _formatTime(ts);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDone ? Colors.grey[100] : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDone ? 0.04 : 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  onTap: () => _toggleDone(docId, isDone),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: isDone
                                          ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[500]!])
                                          : const LinearGradient(
                                              colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isDone ? Icons.check_circle : Icons.alarm,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDone ? Colors.grey[600] : const Color(0xFF2E5AAC),
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          timeText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4A90E2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                        color: isDone ? const Color(0xFF66BB6A) : const Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}