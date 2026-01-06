import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/note_model.dart';
import '../services/reminder_service.dart';

class ReminderDialog extends StatefulWidget {
  final ReminderModel? existingReminder;
  final Function(ReminderModel?) onReminderSet;

  const ReminderDialog({
    super.key,
    this.existingReminder,
    required this.onReminderSet,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReminderService _reminderService = ReminderService();

  // Time-based reminder fields
  DateTime? _selectedDateTime;
  bool _isRecurring = false;
  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.daily;
  final TextEditingController _naturalLanguageController =
      TextEditingController();

  // Location-based reminder fields
  double? _latitude;
  double? _longitude;
  double _radiusMeters = 100.0;
  final TextEditingController _locationNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize with existing reminder if provided
    if (widget.existingReminder != null) {
      final reminder = widget.existingReminder!;
      if (reminder.type == ReminderType.time) {
        _tabController.index = 0;
        _selectedDateTime = reminder.triggerTime;
        _isRecurring = reminder.recurring;
        if (reminder.pattern != null) {
          _recurrenceFrequency = reminder.pattern!.frequency;
        }
      } else {
        _tabController.index = 1;
        _latitude = reminder.latitude;
        _longitude = reminder.longitude;
        _radiusMeters = reminder.radiusMeters ?? 100.0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _naturalLanguageController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Set Reminder',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.access_time), text: 'Time'),
                Tab(icon: Icon(Icons.location_on), text: 'Location'),
              ],
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTimeReminderTab(),
                  _buildLocationReminderTab(),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existingReminder != null)
                    TextButton.icon(
                      onPressed: () {
                        widget.onReminderSet(null);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveReminder,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeReminderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Natural language input
          Text('Quick Input', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _naturalLanguageController,
            decoration: InputDecoration(
              hintText: 'e.g., tomorrow, next Monday, in 2 hours',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                onPressed: _parseNaturalLanguage,
              ),
            ),
            onSubmitted: (_) => _parseNaturalLanguage(),
          ),
          const SizedBox(height: 16),

          const Divider(),
          const SizedBox(height: 16),

          // Date and time picker
          Text(
            'Specific Date & Time',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Selected date time display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDateTime != null
                        ? _formatDateTime(_selectedDateTime!)
                        : 'No date selected',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _pickDateTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recurring option
          SwitchListTile(
            title: const Text('Recurring Reminder'),
            value: _isRecurring,
            onChanged: (value) {
              setState(() {
                _isRecurring = value;
              });
            },
          ),

          // Recurrence frequency
          if (_isRecurring) ...[
            const SizedBox(height: 8),
            Text('Repeat', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<RecurrenceFrequency>(
              segments: const [
                ButtonSegment(
                  value: RecurrenceFrequency.daily,
                  label: Text('Daily'),
                  icon: Icon(Icons.today),
                ),
                ButtonSegment(
                  value: RecurrenceFrequency.weekly,
                  label: Text('Weekly'),
                  icon: Icon(Icons.date_range),
                ),
                ButtonSegment(
                  value: RecurrenceFrequency.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {_recurrenceFrequency},
              onSelectionChanged: (Set<RecurrenceFrequency> newSelection) {
                setState(() {
                  _recurrenceFrequency = newSelection.first;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationReminderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Location name
          TextField(
            controller: _locationNameController,
            decoration: const InputDecoration(
              labelText: 'Location Name',
              hintText: 'e.g., Home, Office, Grocery Store',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
          ),
          const SizedBox(height: 16),

          // Current location button
          ElevatedButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Use Current Location'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),

          // Selected location display
          if (_latitude != null && _longitude != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location Set',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Lat: ${_latitude!.toStringAsFixed(6)}, '
                          'Lng: ${_longitude!.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Radius slider
          Text(
            'Trigger Radius: ${_radiusMeters.toInt()} meters',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Slider(
            value: _radiusMeters,
            min: 50,
            max: 1000,
            divisions: 19,
            label: '${_radiusMeters.toInt()}m',
            onChanged: (value) {
              setState(() {
                _radiusMeters = value;
              });
            },
          ),
          Text(
            'You\'ll be notified when you\'re within ${_radiusMeters.toInt()} meters of this location',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _parseNaturalLanguage() {
    final input = _naturalLanguageController.text.trim();
    if (input.isEmpty) return;

    final parsedTime = _reminderService.parseNaturalLanguageTime(input);
    if (parsedTime != null) {
      setState(() {
        _selectedDateTime = parsedTime;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${_formatDateTime(parsedTime)}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not understand the time expression'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. '
                'Please enable it in settings.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location captured'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveReminder() {
    if (_tabController.index == 0) {
      // Time-based reminder
      if (_selectedDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date and time'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final reminder = ReminderModel(
        id:
            widget.existingReminder?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: ReminderType.time,
        triggerTime: _selectedDateTime,
        recurring: _isRecurring,
        pattern:
            _isRecurring
                ? RecurrencePattern(
                  frequency: _recurrenceFrequency,
                  interval: 1,
                )
                : null,
      );

      widget.onReminderSet(reminder);
      Navigator.pop(context);
    } else {
      // Location-based reminder
      if (_latitude == null || _longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set a location'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final reminder = ReminderModel(
        id:
            widget.existingReminder?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        type: ReminderType.location,
        latitude: _latitude,
        longitude: _longitude,
        radiusMeters: _radiusMeters,
      );

      widget.onReminderSet(reminder);
      Navigator.pop(context);
    }
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
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$dateStr at $displayHour:$minute $period';
  }
}
