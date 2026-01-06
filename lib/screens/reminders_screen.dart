import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../screens/edit_note_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  List<NoteWithReminder> _notesWithReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh reminders when screen comes back into focus
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      // Get all notes
      final notesResult = await _supabaseService.getAllNotes();

      if (!notesResult.success || notesResult.data == null) {
        throw Exception(notesResult.error ?? 'Failed to load notes');
      }

      // Filter notes with reminders
      final notesWithReminders =
          notesResult.data!
              .where((note) => note.reminder != null)
              .map(
                (note) =>
                    NoteWithReminder(note: note, reminder: note.reminder!),
              )
              .toList();

      // Sort by trigger time (time-based reminders first, then location-based)
      notesWithReminders.sort((a, b) {
        if (a.reminder.type == ReminderType.time &&
            b.reminder.type == ReminderType.time) {
          if (a.reminder.triggerTime == null) return 1;
          if (b.reminder.triggerTime == null) return -1;
          return a.reminder.triggerTime!.compareTo(b.reminder.triggerTime!);
        } else if (a.reminder.type == ReminderType.time) {
          return -1;
        } else {
          return 1;
        }
      });

      setState(() {
        _notesWithReminders = notesWithReminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reminders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notesWithReminders.isEmpty
              ? _buildEmptyState()
              : _buildRemindersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Reminders',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add reminders to your notes to see them here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList() {
    // Group reminders by type
    final timeReminders =
        _notesWithReminders
            .where((item) => item.reminder.type == ReminderType.time)
            .toList();
    final locationReminders =
        _notesWithReminders
            .where((item) => item.reminder.type == ReminderType.location)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (timeReminders.isNotEmpty) ...[
          _buildSectionHeader('Time-Based Reminders', Icons.access_time),
          const SizedBox(height: 12),
          ...timeReminders.map((item) => _buildReminderCard(item)),
          const SizedBox(height: 24),
        ],
        if (locationReminders.isNotEmpty) ...[
          _buildSectionHeader('Location-Based Reminders', Icons.location_on),
          const SizedBox(height: 12),
          ...locationReminders.map((item) => _buildReminderCard(item)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReminderCard(NoteWithReminder item) {
    final note = item.note;
    final reminder = item.reminder;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _openNote(note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 8),

              // Note description preview
              if (note.description.isNotEmpty)
                Text(
                  note.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              const Divider(),
              const SizedBox(height: 8),

              // Reminder details
              if (reminder.type == ReminderType.time)
                _buildTimeReminderDetails(reminder)
              else
                _buildLocationReminderDetails(reminder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeReminderDetails(ReminderModel reminder) {
    final triggerTime = reminder.triggerTime;
    if (triggerTime == null) {
      return const Text('Invalid reminder time');
    }

    final now = DateTime.now();
    final isPast = triggerTime.isBefore(now);
    final timeUntil = _getTimeUntilString(triggerTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 20,
              color:
                  isPast ? Colors.red : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatDateTime(triggerTime),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isPast ? Colors.red : null,
                ),
              ),
            ),
          ],
        ),
        if (!isPast) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              timeUntil,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        ],
        if (reminder.recurring && reminder.pattern != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.repeat, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                _getRecurrenceString(reminder.pattern!),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocationReminderDetails(ReminderModel reminder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.place,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location: ${reminder.latitude?.toStringAsFixed(4)}, '
                '${reminder.longitude?.toStringAsFixed(4)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            'Radius: ${reminder.radiusMeters?.toInt() ?? 0} meters',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  void _openNote(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)),
    ).then((_) => _loadReminders());
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (dateToCheck == today) {
      dateStr = 'Today';
    } else if (dateToCheck == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      final weekday = _getWeekdayName(dateTime.weekday);
      dateStr = '$weekday, ${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dateStr at $displayHour:$minute $period';
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  String _getTimeUntilString(DateTime triggerTime) {
    final now = DateTime.now();
    final difference = triggerTime.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    }

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'in less than a minute';
    }
  }

  String _getRecurrenceString(RecurrencePattern pattern) {
    switch (pattern.frequency) {
      case RecurrenceFrequency.daily:
        return 'Repeats daily';
      case RecurrenceFrequency.weekly:
        return 'Repeats weekly';
      case RecurrenceFrequency.monthly:
        return 'Repeats monthly';
    }
  }
}

class NoteWithReminder {
  final NoteModel note;
  final ReminderModel reminder;

  NoteWithReminder({required this.note, required this.reminder});
}
