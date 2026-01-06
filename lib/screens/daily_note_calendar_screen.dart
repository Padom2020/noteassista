import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/feature_tooltip.dart';
import '../utils/user_extensions.dart';
import 'edit_note_screen.dart';
import 'daily_note_settings_screen.dart';

class DailyNoteCalendarScreen extends StatefulWidget {
  const DailyNoteCalendarScreen({super.key});

  @override
  State<DailyNoteCalendarScreen> createState() =>
      _DailyNoteCalendarScreenState();
}

class _DailyNoteCalendarScreenState extends State<DailyNoteCalendarScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, bool> _datesWithNotes = {};
  int _currentStreak = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDatesWithNotes();
    _calculateStreak();
  }

  Future<void> _loadDatesWithNotes() async {
    final userId = _authService.currentUser.safeUid;
    if (userId == null || !_authService.currentUser.isAuthenticated) {
      debugPrint(
        'DailyNoteCalendar: Cannot load dates - user not authenticated',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
        'DailyNoteCalendar: Loading dates with notes for user: $userId',
      );

      // Get all notes with "daily" tag
      final result = await _supabaseService.getAllNotes();

      if (!result.success || result.data == null) {
        debugPrint('Failed to load notes: ${result.error}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final notes = result.data!;
      final Map<DateTime, bool> datesMap = {};

      for (var note in notes) {
        try {
          if (note.tags.contains('daily')) {
            // Extract date from title "Daily Note - YYYY-MM-DD"
            final titleParts = note.title.split(' - ');
            if (titleParts.length == 2) {
              final dateParts = titleParts[1].split('-');
              if (dateParts.length == 3) {
                final date = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
                datesMap[_normalizeDate(date)] = true;
              }
            }
          }
        } catch (e) {
          debugPrint('DailyNoteCalendar: Error processing note document: $e');
          // Continue processing other notes
        }
      }

      if (mounted) {
        setState(() {
          _datesWithNotes = datesMap;
          _isLoading = false;
        });
        debugPrint(
          'DailyNoteCalendar: Loaded ${datesMap.length} dates with notes',
        );
      }
    } catch (e) {
      debugPrint('DailyNoteCalendar: Error loading calendar data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading calendar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadDatesWithNotes,
            ),
          ),
        );
      }
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _calculateStreak() async {
    final userId = _authService.currentUser.safeUid;
    if (userId == null || !_authService.currentUser.isAuthenticated) {
      return;
    }

    try {
      // Get all daily notes sorted by date
      final result = await _supabaseService.getAllNotes();

      if (!result.success || result.data == null) {
        return;
      }

      final notes = result.data!;
      final List<DateTime> dailyNoteDates = [];

      for (var note in notes) {
        if (note.tags.contains('daily')) {
          final titleParts = note.title.split(' - ');
          if (titleParts.length == 2) {
            try {
              final dateParts = titleParts[1].split('-');
              if (dateParts.length == 3) {
                final date = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
                dailyNoteDates.add(_normalizeDate(date));
              }
            } catch (e) {
              // Skip invalid dates
            }
          }
        }
      }

      // Sort dates in descending order
      dailyNoteDates.sort((a, b) => b.compareTo(a));

      // Calculate streak starting from today
      int streak = 0;
      final today = _normalizeDate(DateTime.now());

      if (dailyNoteDates.contains(today)) {
        streak = 1;
        DateTime checkDate = today.subtract(const Duration(days: 1));

        while (dailyNoteDates.contains(checkDate)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }

      if (mounted) {
        setState(() {
          _currentStreak = streak;
        });
      }
    } catch (e) {
      // Silently fail streak calculation
    }
  }

  Future<void> _openDailyNote(DateTime date) async {
    final userId = _authService.currentUser.safeUid;
    if (userId == null || !_authService.currentUser.isAuthenticated) {
      debugPrint(
        'DailyNoteCalendar: Cannot open daily note - user not authenticated',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to access daily notes'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to login or trigger auth flow
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
        'DailyNoteCalendar: Opening daily note for date: ${date.toIso8601String()}',
      );
      final noteResult = await _supabaseService.getDailyNoteForDate(
        userId,
        date,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (noteResult.success && noteResult.data != null) {
          // Navigate to edit screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(note: noteResult.data!),
            ),
          );

          // Reload calendar if note was edited
          if (result == true) {
            _loadDatesWithNotes();
            _calculateStreak();
          }
        } else {
          // Handle error or create new note
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not load daily note: ${noteResult.error ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('DailyNoteCalendar: Error opening daily note: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening daily note: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _openDailyNote(date),
            ),
          ),
        );
      }
    }
  }

  void _navigateToPreviousDay() {
    final previousDay = _selectedDay!.subtract(const Duration(days: 1));
    setState(() {
      _selectedDay = previousDay;
      _focusedDay = previousDay;
    });
    _openDailyNote(previousDay);
  }

  void _navigateToNextDay() {
    final nextDay = _selectedDay!.add(const Duration(days: 1));
    setState(() {
      _selectedDay = nextDay;
      _focusedDay = nextDay;
    });
    _openDailyNote(nextDay);
  }

  Future<void> _openWeeklyNote() async {
    final userId = _authService.currentUser.safeUid;
    if (userId == null || !_authService.currentUser.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to access weekly notes'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final noteResult = await _supabaseService.getWeeklyNoteForDate(
        userId,
        _selectedDay ?? DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (noteResult.success && noteResult.data != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(note: noteResult.data!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not load weekly note: ${noteResult.error ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening weekly note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openMonthlyNote() async {
    final userId = _authService.currentUser.safeUid;
    if (userId == null || !_authService.currentUser.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to access monthly notes'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final noteResult = await _supabaseService.getMonthlyNoteForDate(
        userId,
        _selectedDay ?? DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (noteResult.success && noteResult.data != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditNoteScreen(note: noteResult.data!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not load monthly note: ${noteResult.error ?? "Unknown error"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening monthly note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    if (!_authService.currentUser.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Notes')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to access daily notes',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Notes'),
        actions: [
          // Settings button
          FeatureTooltip(
            tooltipId: 'daily_note_settings_feature',
            message: 'Customize your daily note template and preferences',
            direction: TooltipDirection.bottom,
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyNoteSettingsScreen(),
                  ),
                );
              },
              tooltip: 'Daily Note Settings',
            ),
          ),
          // Streak counter
          if (_currentStreak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '$_currentStreak day${_currentStreak > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Calendar widget
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          calendarFormat: _calendarFormat,
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            _openDailyNote(selectedDay);
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: BoxDecoration(
                              color: Colors.green[600],
                              shape: BoxShape.circle,
                            ),
                            markersMaxCount: 1,
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final normalizedDate = _normalizeDate(date);
                              if (_datesWithNotes.containsKey(normalizedDate)) {
                                return Positioned(
                                  bottom: 1,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),

                    // Navigation buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _navigateToPreviousDay,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous Day'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _navigateToNextDay,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next Day'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Weekly and Monthly Note Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openWeeklyNote,
                              icon: const Icon(Icons.calendar_view_week),
                              label: const Text('Weekly Note'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.blue[100],
                                foregroundColor: Colors.blue[900],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openMonthlyNote,
                              icon: const Icon(Icons.calendar_month),
                              label: const Text('Monthly Note'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.purple[100],
                                foregroundColor: Colors.purple[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Info card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Daily Notes',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '• Tap any date to open or create a daily note',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text(
                                    '• Dates with ',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Text(
                                    ' have existing notes',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '• Use navigation buttons to move between days',
                                style: TextStyle(fontSize: 14),
                              ),
                              if (_currentStreak > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '• Keep your streak going! 🔥',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final today = DateTime.now();
          setState(() {
            _selectedDay = today;
            _focusedDay = today;
          });
          await _openDailyNote(today);
        },
        icon: const Icon(Icons.today),
        label: const Text('Today'),
      ),
    );
  }
}
