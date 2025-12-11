import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for handling collaboration-related notifications
class CollaborationNotificationService {
  static final CollaborationNotificationService _instance =
      CollaborationNotificationService._internal();
  factory CollaborationNotificationService() => _instance;
  CollaborationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configure Android notification channel for collaboration
    const AndroidNotificationChannel collaborationChannel =
        AndroidNotificationChannel(
          'collaboration_notifications',
          'Collaboration Notifications',
          description: 'Notifications for note sharing and collaboration',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );

    // Create notification channel for Android
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(collaborationChannel);

    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'collaboration',
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(
                  'open_note',
                  'Open Note',
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

    await _notificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  /// Send notification to new collaborators when they're added to a note
  Future<void> notifyNewCollaborators({
    required String noteId,
    required String noteTitle,
    required String ownerName,
    required List<String> newCollaboratorIds,
    required String ownerId,
  }) async {
    try {
      await initialize();

      // For each new collaborator, send a notification
      for (final collaboratorId in newCollaboratorIds) {
        await _sendCollaboratorAddedNotification(
          collaboratorId: collaboratorId,
          noteId: noteId,
          noteTitle: noteTitle,
          ownerName: ownerName,
          ownerId: ownerId,
        );
      }
    } catch (e) {
      // Log error but don't throw to avoid breaking the sharing process
      if (kDebugMode) {
        print('Error sending collaboration notifications: $e');
      }
    }
  }

  /// Send a notification to a specific collaborator
  Future<void> _sendCollaboratorAddedNotification({
    required String collaboratorId,
    required String noteId,
    required String noteTitle,
    required String ownerName,
    required String ownerId,
  }) async {
    try {
      // Generate unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

      // Create notification payload
      final payload = '$noteId|$ownerId|collaboration_added';

      // Configure Android notification details
      final AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        'collaboration_notifications',
        'Collaboration Notifications',
        channelDescription: 'Notifications for note sharing and collaboration',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          'You can now view and edit this note together with $ownerName.',
          htmlFormatBigText: false,
          contentTitle: 'Added to "$noteTitle"',
          htmlFormatContentTitle: false,
          summaryText: 'NoteAssista Collaboration',
          htmlFormatSummaryText: false,
        ),
      );

      // Configure iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'collaboration',
        threadIdentifier: 'collaboration_notifications',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Create notification details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _notificationsPlugin.show(
        notificationId,
        'Added to "$noteTitle"',
        '$ownerName shared a note with you',
        notificationDetails,
        payload: payload,
      );

      // Store notification in Firestore for the collaborator
      await _storeNotificationInFirestore(
        collaboratorId: collaboratorId,
        noteId: noteId,
        noteTitle: noteTitle,
        ownerName: ownerName,
        ownerId: ownerId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification to collaborator $collaboratorId: $e');
      }
    }
  }

  /// Store notification in Firestore for cross-device sync
  Future<void> _storeNotificationInFirestore({
    required String collaboratorId,
    required String noteId,
    required String noteTitle,
    required String ownerName,
    required String ownerId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(collaboratorId)
          .collection('notifications')
          .add({
            'type': 'collaboration_added',
            'noteId': noteId,
            'noteTitle': noteTitle,
            'ownerName': ownerName,
            'ownerId': ownerId,
            'message': '$ownerName shared "$noteTitle" with you',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'actionUrl': '/note/$ownerId/$noteId',
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error storing notification in Firestore: $e');
      }
    }
  }

  /// Send notification when someone comments on a shared note
  Future<void> notifyCollaboratorsOfComment({
    required String noteId,
    required String noteTitle,
    required String commenterName,
    required String comment,
    required List<String> collaboratorIds,
    required String ownerId,
  }) async {
    try {
      await initialize();

      for (int i = 0; i < collaboratorIds.length; i++) {
        final notificationId =
            DateTime.now().millisecondsSinceEpoch % 2147483647;
        final payload = '$noteId|$ownerId|collaboration_comment';

        final AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
              'collaboration_notifications',
              'Collaboration Notifications',
              channelDescription:
                  'Notifications for note sharing and collaboration',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              styleInformation: BigTextStyleInformation(
                comment,
                htmlFormatBigText: false,
                contentTitle: '$commenterName commented on "$noteTitle"',
                htmlFormatContentTitle: false,
                summaryText: 'NoteAssista Collaboration',
                htmlFormatSummaryText: false,
              ),
            );

        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          categoryIdentifier: 'collaboration',
          threadIdentifier: 'collaboration_notifications',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        await _notificationsPlugin.show(
          notificationId + i, // Make notification ID unique
          '$commenterName commented',
          'On "$noteTitle"',
          notificationDetails,
          payload: payload,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending comment notifications: $e');
      }
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markNotificationsAsRead(String userId) async {
    try {
      final notifications =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notifications as read: $e');
      }
    }
  }

  /// Get unread notification count for a user
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final notifications =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .get();

      return notifications.docs.length;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting unread notification count: $e');
      }
      return 0;
    }
  }

  /// Get notifications stream for a user
  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}
