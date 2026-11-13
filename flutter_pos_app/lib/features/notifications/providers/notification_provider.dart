import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../data/models/notification_model.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  // Track in-flight restock requests per productId to prevent duplicates from tap bubbling
  final Set<String> _sendingRestockFor = {};

  StreamSubscription<RemoteMessage>? _messagingSubscription;
  Timer? _pollingTimer;
  final Set<String> _seenNotifIds = <String>{};
  bool _initialFetchDone = false;

  NotificationNotifier() : super(NotificationState()) {
    fetchNotifications();
    
    // Listen to foreground pushes to automatically refresh unread count
    _messagingSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      fetchNotifications();
    });

    // Periodic poller (every 8 seconds) so user gets instant phone notification in real-time
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      fetchNotifications();
    });
  }

  @override
  void dispose() {
    _messagingSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await SessionService.getToken();
      if (token == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.notifications}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> notifs = data['notifications'] ?? [];
          final unread = data['unreadCount'] ?? 0;
          final notifList = notifs.map((n) => AppNotification.fromJson(n)).toList();

          if (!_initialFetchDone) {
            _initialFetchDone = true;
            for (final n in notifList) {
              _seenNotifIds.add(n.id);
            }
          } else {
            // Check for new notifications to fire phone heads-up push alert
            for (final n in notifList) {
              if (!_seenNotifIds.contains(n.id)) {
                _seenNotifIds.add(n.id);
                PushNotificationService.showLocalNotification(
                  id: n.id.hashCode,
                  title: n.title,
                  body: n.message,
                );
              }
            }
          }

          state = state.copyWith(
            notifications: notifList,
            unreadCount: unread,
            isLoading: false,
          );
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAsRead() async {
    if (state.unreadCount == 0) return;
    
    // Optimistically update UI
    state = state.copyWith(unreadCount: 0);
    
    try {
      final token = await SessionService.getToken();
      if (token == null) return;

      await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.notifications}/read'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  Future<bool> requestRestock(String productId, String productName, {bool isFromPos = false}) async {
    // Prevent duplicate API calls from event bubbling or rapid taps
    if (_sendingRestockFor.contains(productId)) {
      debugPrint('[Notification] Duplicate restock request blocked for $productName');
      return false;
    }
    _sendingRestockFor.add(productId);
    try {
      final token = await SessionService.getToken();
      if (token == null) return false;

      final noteStr = isFromPos 
          ? 'POS Alert: Cashier reported $productName is completely out of stock at the counter.'
          : 'Low Stock Alert for $productName from Dashboard.';

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.notificationRestockRequest}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'productId': productId,
          'note': noteStr,
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error requesting restock: $e");
      return false;
    } finally {
      // Release after a short cooldown so rapid double-taps are still blocked
      await Future.delayed(const Duration(seconds: 3));
      _sendingRestockFor.remove(productId);
    }
  }

  Future<bool> remindInventoryManager(String messageStr) async {
    try {
      final token = await SessionService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/api/notifications/broadcast'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': 'Admin Reminder 🔔',
          'message': messageStr,
          'targetRoles': ['inventory'],
          'type': 'general',
        }),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Error sending reminder: $e");
      return false;
    }
  }
}

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
