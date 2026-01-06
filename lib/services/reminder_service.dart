import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../models/note_model.dart';

/// Service for managing note reminders with notification support.
///
/// Features:
/// - Time-based reminders with recurring options
/// - Location-based reminders with geofencing
/// - Rich notifications with actions (snooze, mark done)
/// - Graceful permission handling
/// - Platform-specific notification channels (Android) and categories (iOS)
///
/// Notification Channels (Android):
/// - note_reminders: For time-based reminders
/// - location_reminders: For location-based reminders
///
/// Notification Categories (iOS):
/// - noteReminder: Category with snooze and mark done actions
///
/// Usage:
/// ```dart
/// final reminderService = ReminderService();
/// await reminderService.initialize();
/// reminderService.onNotificationTapped = (noteId, action) {
///   // Handle notification tap or action
/// };
/// ```
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, StreamSubscription<Position>?> _locationSubscriptions = {};
  final Map<String, ReminderModel> _activeReminders = {};

  /// Callback for notification tap - to be set by the app.
  /// Parameters:
  /// - noteId: The ID of the note associated with the reminder
  /// - action: The action ID ('snooze', 'mark_done', or null for default tap)
  Function(String noteId, String? action)? onNotificationTapped;

  // Initialize the service
  Future<void> initialize() async {
    // Configure Android notification channels
    const AndroidNotificationChannel noteRemindersChannel =
        AndroidNotificationChannel(
          'note_reminders',
          'Note Reminders',
          description: 'Reminders for your notes',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

    const AndroidNotificationChannel locationRemindersChannel =
        AndroidNotificationChannel(
          'location_reminders',
          'Location Reminders',
          description: 'Location-based reminders for your notes',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

    // Create notification channels for Android
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(noteRemindersChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(locationRemindersChannel);

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configure iOS notification categories with actions
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'noteReminder',
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  'snooze',
                  'Snooze',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
                DarwinNotificationAction.plain(
                  'mark_done',
                  'Mark Done',
                  options: <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  },
                ),
              ],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request notification permissions gracefully
    await _requestNotificationPermissionGracefully();
  }

  // Handle notification response (tap or action)
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    // Parse the payload to get noteId
    final parts = payload.split('|');
    final noteId = parts[0];
    final action = response.actionId;

    // Call the callback if set
    if (onNotificationTapped != null) {
      onNotificationTapped!(noteId, action);
    }
  }

  // Request notification permission gracefully
  Future<bool> _requestNotificationPermissionGracefully() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    // Check if we should show rationale
    if (await Permission.notification.shouldShowRequestRationale) {
      // In a real app, show a dialog explaining why we need the permission
      // For now, just request it
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  // Schedule a time-based reminder
  Future<void> scheduleTimeReminder(
    String noteId,
    DateTime triggerTime, {
    bool recurring = false,
    RecurrencePattern? pattern,
  }) async {
    // Request notification permission
    final hasPermission = await _requestNotificationPermission();
    if (!hasPermission) {
      throw Exception('Notification permission denied');
    }

    final reminderId = _generateReminderId();
    final reminder = ReminderModel(
      id: reminderId,
      type: ReminderType.time,
      triggerTime: triggerTime,
      recurring: recurring,
      pattern: pattern,
    );

    _activeReminders[reminderId] = reminder;

    if (recurring && pattern != null) {
      await _scheduleRecurringNotification(noteId, reminder);
    } else {
      await _scheduleSingleNotification(noteId, reminder);
    }
  }

  // Schedule a location-based reminder
  Future<void> scheduleLocationReminder(
    String noteId,
    double latitude,
    double longitude,
    double radiusMeters,
  ) async {
    // Request location permission
    final hasLocationPermission = await _requestLocationPermission();
    if (!hasLocationPermission) {
      throw Exception('Location permission denied');
    }

    // Request notification permission
    final hasNotificationPermission = await _requestNotificationPermission();
    if (!hasNotificationPermission) {
      throw Exception('Notification permission denied');
    }

    final reminderId = _generateReminderId();
    final reminder = ReminderModel(
      id: reminderId,
      type: ReminderType.location,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    _activeReminders[reminderId] = reminder;
    await _startLocationMonitoring(noteId, reminder);
  }

  // Cancel a reminder
  Future<void> cancelReminder(String reminderId) async {
    final reminder = _activeReminders[reminderId];
    if (reminder == null) return;

    if (reminder.type == ReminderType.time) {
      await _notificationsPlugin.cancel(reminderId.hashCode);
    } else if (reminder.type == ReminderType.location) {
      await _stopLocationMonitoring(reminderId);
    }

    _activeReminders.remove(reminderId);
  }

  // Get all active reminders
  Future<List<ReminderModel>> getActiveReminders(String userId) async {
    // In a real implementation, this would fetch from a database
    // For now, return the in-memory active reminders
    return _activeReminders.values.toList();
  }

  // Snooze a reminder for a specified duration (default 10 minutes)
  Future<void> snoozeReminder(
    String noteId,
    String reminderId, {
    Duration duration = const Duration(minutes: 10),
  }) async {
    // Cancel the current reminder
    await cancelReminder(reminderId);

    // Schedule a new reminder for the snooze duration
    final newTriggerTime = DateTime.now().add(duration);
    await scheduleTimeReminder(noteId, newTriggerTime);
  }

  // Mark a note as done (this would typically update the note in Firestore)
  Future<void> markNoteDone(String noteId) async {
    // This is a placeholder - the actual implementation would update
    // the note's isDone status in Firestore
    // The UI layer should handle this by calling FirestoreService
  }

  // Parse natural language time expressions
  DateTime? parseNaturalLanguageTime(String expression) {
    final now = DateTime.now();
    final lowerExpression = expression.toLowerCase().trim();

    // Handle "tomorrow"
    if (lowerExpression == 'tomorrow') {
      return DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    // Handle "next Monday", "next Tuesday", etc.
    final nextDayMatch = RegExp(
      r'next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)',
    ).firstMatch(lowerExpression);
    if (nextDayMatch != null) {
      final dayName = nextDayMatch.group(1)!;
      final targetWeekday = _getWeekdayFromName(dayName);
      final daysUntilTarget = (targetWeekday - now.weekday + 7) % 7;
      final targetDate =
          daysUntilTarget == 0 ? 7 : daysUntilTarget; // Next week if today
      return DateTime(now.year, now.month, now.day + targetDate, 9, 0);
    }

    // Handle "in X hours"
    final hoursMatch = RegExp(
      r'in\s+(\d+)\s+hours?',
    ).firstMatch(lowerExpression);
    if (hoursMatch != null) {
      final hours = int.parse(hoursMatch.group(1)!);
      return now.add(Duration(hours: hours));
    }

    // Handle "in X minutes"
    final minutesMatch = RegExp(
      r'in\s+(\d+)\s+minutes?',
    ).firstMatch(lowerExpression);
    if (minutesMatch != null) {
      final minutes = int.parse(minutesMatch.group(1)!);
      return now.add(Duration(minutes: minutes));
    }

    // Handle "next week"
    if (lowerExpression == 'next week') {
      return DateTime(now.year, now.month, now.day + 7, 9, 0);
    }

    // Handle "today at X PM/AM"
    final todayTimeMatch = RegExp(
      r'today\s+at\s+(\d{1,2})\s*(am|pm)',
      caseSensitive: false,
    ).firstMatch(lowerExpression);
    if (todayTimeMatch != null) {
      final hour = int.parse(todayTimeMatch.group(1)!);
      final period = todayTimeMatch.group(2)!;
      final adjustedHour =
          period == 'pm' && hour != 12
              ? hour + 12
              : period == 'am' && hour == 12
              ? 0
              : hour;
      return DateTime(now.year, now.month, now.day, adjustedHour, 0);
    }

    return null;
  }

  // Monitor location for geofence triggers
  Stream<LocationEvent> monitorLocation() {
    final controller = StreamController<LocationEvent>();

    // Start location monitoring
    _startGlobalLocationMonitoring(controller);

    return controller.stream;
  }

  // Private helper methods

  String _generateReminderId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  Future<bool> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      // Also request location when in use
      final locationWhenInUse = await Permission.locationWhenInUse.request();
      return locationWhenInUse.isGranted;
    }
    return false;
  }

  int _getWeekdayFromName(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  Future<void> _scheduleSingleNotification(
    String noteId,
    ReminderModel reminder,
  ) async {
    if (reminder.triggerTime == null) return;

    // Calculate notification time
    final scheduledDate = reminder.triggerTime!;

    // Create notification details with actions
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'note_reminders',
        'Note Reminders',
        channelDescription: 'Reminders for your notes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'snooze',
            'Snooze',
            icon: DrawableResourceAndroidBitmap('ic_snooze'),
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'mark_done',
            'Mark Done',
            icon: DrawableResourceAndroidBitmap('ic_check'),
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'noteReminder',
      ),
    );

    // For immediate or past notifications, show immediately
    if (scheduledDate.isBefore(DateTime.now())) {
      await _notificationsPlugin.show(
        reminder.id.hashCode,
        'Note Reminder',
        'You have a reminder for your note',
        notificationDetails,
        payload: '$noteId|${reminder.id}',
      );
    } else {
      // Schedule for future time using zonedSchedule
      // This works on both Android and iOS
      try {
        // Initialize timezone data
        tzdata.initializeTimeZones();

        await _notificationsPlugin.zonedSchedule(
          reminder.id.hashCode,
          'Note Reminder',
          'You have a reminder for your note',
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '$noteId|${reminder.id}',
        );
      } catch (e) {
        debugPrint('Error scheduling notification: $e');
        // Fallback to delayed show if zonedSchedule fails
        final delay = scheduledDate.difference(DateTime.now());
        Future.delayed(delay, () {
          _notificationsPlugin.show(
            reminder.id.hashCode,
            'Note Reminder',
            'You have a reminder for your note',
            notificationDetails,
            payload: '$noteId|${reminder.id}',
          );
        });
      }
    }
  }

  Future<void> _scheduleRecurringNotification(
    String noteId,
    ReminderModel reminder,
  ) async {
    if (reminder.triggerTime == null || reminder.pattern == null) return;

    RepeatInterval? repeatInterval;
    switch (reminder.pattern!.frequency) {
      case RecurrenceFrequency.daily:
        repeatInterval = RepeatInterval.daily;
        break;
      case RecurrenceFrequency.weekly:
        repeatInterval = RepeatInterval.weekly;
        break;
      default:
        // Monthly not directly supported, schedule single for now
        await _scheduleSingleNotification(noteId, reminder);
        return;
    }

    await _notificationsPlugin.periodicallyShow(
      reminder.id.hashCode,
      'Note Reminder',
      'You have a recurring reminder for your note',
      repeatInterval,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'note_reminders',
          'Note Reminders',
          channelDescription: 'Reminders for your notes',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'snooze',
              'Snooze',
              icon: DrawableResourceAndroidBitmap('ic_snooze'),
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'mark_done',
              'Mark Done',
              icon: DrawableResourceAndroidBitmap('ic_check'),
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'noteReminder',
        ),
      ),
      payload: '$noteId|${reminder.id}',
    );
  }

  Future<void> _startLocationMonitoring(
    String noteId,
    ReminderModel reminder,
  ) async {
    if (reminder.latitude == null ||
        reminder.longitude == null ||
        reminder.radiusMeters == null) {
      return;
    }

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    final subscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final distance = Geolocator.distanceBetween(
        reminder.latitude!,
        reminder.longitude!,
        position.latitude,
        position.longitude,
      );

      if (distance <= reminder.radiusMeters!) {
        _triggerLocationReminder(noteId, reminder);
      }
    });

    _locationSubscriptions[reminder.id] = subscription;
  }

  Future<void> _stopLocationMonitoring(String reminderId) async {
    final subscription = _locationSubscriptions[reminderId];
    if (subscription != null) {
      await subscription.cancel();
      _locationSubscriptions.remove(reminderId);
    }
  }

  void _triggerLocationReminder(String noteId, ReminderModel reminder) {
    _notificationsPlugin.show(
      reminder.id.hashCode,
      'Location Reminder',
      'You\'ve arrived at your reminder location',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'location_reminders',
          'Location Reminders',
          channelDescription: 'Location-based reminders for your notes',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'snooze',
              'Snooze',
              icon: DrawableResourceAndroidBitmap('ic_snooze'),
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'mark_done',
              'Mark Done',
              icon: DrawableResourceAndroidBitmap('ic_check'),
              showsUserInterface: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'noteReminder',
        ),
      ),
      payload: '$noteId|${reminder.id}',
    );

    // Remove the reminder after triggering (one-time location reminders)
    cancelReminder(reminder.id);
  }

  void _startGlobalLocationMonitoring(
    StreamController<LocationEvent> controller,
  ) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        controller.add(
          LocationEvent(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
          ),
        );
      },
      onError: (error) {
        controller.addError(error);
      },
    );
  }
}

// Location event class for the monitoring stream
class LocationEvent {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationEvent({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}
