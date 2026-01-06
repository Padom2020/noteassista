import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../models/daily_note_preferences.dart';

class DailyNoteSettingsScreen extends StatefulWidget {
  const DailyNoteSettingsScreen({super.key});

  @override
  State<DailyNoteSettingsScreen> createState() =>
      _DailyNoteSettingsScreenState();
}

class _DailyNoteSettingsScreenState extends State<DailyNoteSettingsScreen> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  DailyNotePreferences _preferences = DailyNotePreferences();

  final TextEditingController _dailyTemplateController =
      TextEditingController();
  final TextEditingController _weeklyTemplateController =
      TextEditingController();
  final TextEditingController _monthlyTemplateController =
      TextEditingController();

  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _dailyTemplateController.dispose();
    _weeklyTemplateController.dispose();
    _monthlyTemplateController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _supabaseService.getDailyNotePreferences(userId);

      if (result.success && result.data != null) {
        final preferences = DailyNotePreferences.fromMap(result.data!);

        setState(() {
          _preferences = preferences;
          _dailyTemplateController.text =
              preferences.customDailyTemplate ??
              DailyNotePreferences.getDefaultDailyTemplate();
          _weeklyTemplateController.text =
              preferences.customWeeklyTemplate ??
              DailyNotePreferences.getDefaultWeeklyTemplate();
          _monthlyTemplateController.text =
              preferences.customMonthlyTemplate ??
              DailyNotePreferences.getDefaultMonthlyTemplate();

          if (preferences.autoCreateTime != null) {
            final parts = preferences.autoCreateTime!.split(':');
            if (parts.length == 2) {
              _selectedTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }

          _isLoading = false;
        });
      } else {
        // Handle error or use default preferences
        setState(() {
          _preferences = DailyNotePreferences();
          _dailyTemplateController.text =
              DailyNotePreferences.getDefaultDailyTemplate();
          _weeklyTemplateController.text =
              DailyNotePreferences.getDefaultWeeklyTemplate();
          _monthlyTemplateController.text =
              DailyNotePreferences.getDefaultMonthlyTemplate();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedPreferences = _preferences.copyWith(
        customDailyTemplate: _dailyTemplateController.text,
        customWeeklyTemplate: _weeklyTemplateController.text,
        customMonthlyTemplate: _monthlyTemplateController.text,
        autoCreateTime:
            _selectedTime != null
                ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                : null,
      );

      await _supabaseService.saveDailyNotePreferences(
        userId,
        updatedPreferences.toMap(),
      );

      setState(() {
        _preferences = updatedPreferences;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _resetToDefault(DailyNoteType type) {
    setState(() {
      switch (type) {
        case DailyNoteType.daily:
          _dailyTemplateController.text =
              DailyNotePreferences.getDefaultDailyTemplate();
          break;
        case DailyNoteType.weekly:
          _weeklyTemplateController.text =
              DailyNotePreferences.getDefaultWeeklyTemplate();
          break;
        case DailyNoteType.monthly:
          _monthlyTemplateController.text =
              DailyNotePreferences.getDefaultMonthlyTemplate();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Note Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Note Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePreferences,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Use Custom Templates Switch
          Card(
            child: SwitchListTile(
              title: const Text('Use Custom Templates'),
              subtitle: const Text(
                'Enable to use your customized templates instead of defaults',
                softWrap: true,
              ),
              value: _preferences.useCustomTemplate,
              onChanged: (value) {
                setState(() {
                  _preferences = _preferences.copyWith(
                    useCustomTemplate: value,
                  );
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Auto-create Daily Note
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-create Daily Note'),
                  subtitle: const Text(
                    'Automatically create a daily note at a specified time',
                    softWrap: true,
                  ),
                  value: _preferences.autoCreateDaily,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(
                        autoCreateDaily: value,
                      );
                    });
                  },
                ),
                if (_preferences.autoCreateDaily)
                  ListTile(
                    title: const Text('Creation Time'),
                    subtitle: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Not set',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectTime,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Daily Template Section
          _buildTemplateSection(
            title: 'Daily Note Template',
            controller: _dailyTemplateController,
            type: DailyNoteType.daily,
            helpText: 'Available variables: {{date}}, {{year}}, {{month}}',
          ),

          const SizedBox(height: 24),

          // Weekly Template Section
          _buildTemplateSection(
            title: 'Weekly Note Template',
            controller: _weeklyTemplateController,
            type: DailyNoteType.weekly,
            helpText:
                'Available variables: {{week_number}}, {{year}}, {{start_date}}, {{end_date}}, {{month}}',
          ),

          const SizedBox(height: 24),

          // Monthly Template Section
          _buildTemplateSection(
            title: 'Monthly Note Template',
            controller: _monthlyTemplateController,
            type: DailyNoteType.monthly,
            helpText: 'Available variables: {{month}}, {{year}}',
          ),

          const SizedBox(height: 24),

          // Database Diagnostics Section - Hidden from regular users
          // Card(
          //   color: Colors.orange[50],
          //   child: Padding(
          //     padding: const EdgeInsets.all(16.0),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Row(
          //           children: [
          //             Icon(Icons.health_and_safety, color: Colors.orange[700]),
          //             const SizedBox(width: 8),
          //             Expanded(
          //               child: Text(
          //                 'Database Health',
          //                 style: TextStyle(
          //                   fontWeight: FontWeight.bold,
          //                   color: Colors.orange[900],
          //                   fontSize: 16,
          //                 ),
          //               ),
          //             ),
          //           ],
          //         ),
          //         const SizedBox(height: 12),
          //         const Text(
          //           'Run diagnostics to check your database connectivity and schema status.',
          //           style: TextStyle(fontSize: 14),
          //           softWrap: true,
          //         ),
          //         const SizedBox(height: 12),
          //         ElevatedButton.icon(
          //           onPressed: () {
          //             showDialog(
          //               context: context,
          //               builder: (context) => const DatabaseDiagnosticDialog(),
          //             );
          //           },
          //           icon: const Icon(Icons.bug_report),
          //           label: const Text('Run Diagnostics'),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          const SizedBox(height: 24),

          // Info Card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Template Variables',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use variables in your templates to automatically insert dates and other information:',
                    style: TextStyle(fontSize: 14),
                    softWrap: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• {{date}} - Current date (YYYY-MM-DD)',
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                  const Text(
                    '• {{year}} - Current year',
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                  const Text(
                    '• {{month}} - Current month name',
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                  const Text(
                    '• {{week_number}} - Week number (weekly only)',
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                  const Text(
                    '• {{start_date}}, {{end_date}} - Week range (weekly only)',
                    style: TextStyle(fontSize: 13),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _savePreferences,
        icon: const Icon(Icons.save),
        label: const Text('Save Settings'),
      ),
    );
  }

  Widget _buildTemplateSection({
    required String title,
    required TextEditingController controller,
    required DailyNoteType type,
    required String helpText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: TextButton.icon(
                    onPressed: () => _resetToDefault(type),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              helpText,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              softWrap: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Enter your template here...',
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
