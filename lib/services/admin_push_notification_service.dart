import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const AndroidNotificationChannel adminNotificationChannel =
    AndroidNotificationChannel(
      'devi_jewels_admin_orders',
      'Admin Orders',
      description: 'Notifications for new customer orders.',
      importance: Importance.high,
    );

final FlutterLocalNotificationsPlugin adminLocalNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // When the app is in the background, Firebase/Android displays
  // notification messages automatically.
  //
  // Do not perform Supabase/UI navigation work here.
}

class AdminPushNotificationService {
  AdminPushNotificationService({
    required this.supabase,
    this.onOrderNotificationTap,
  });

  final SupabaseClient supabase;

  /// Called when the admin taps an order notification.
  ///
  /// The value is customer_orders.id.
  final Future<void> Function(String orderId)? onOrderNotificationTap;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _adminKey = String.fromEnvironment(
    'NOTIFICATION_ADMIN_KEY',
    defaultValue: '',
  );

  Future<void> initialize() async {
    // This implementation is intentionally Android-only.
    //
    // Your current Mac/Xcode environment cannot support the Firebase
    // iOS SDK version required by the newer FlutterFire packages.
    if (!Platform.isAndroid) {
      return;
    }

    // ------------------------------------------------------------
    // LOCAL NOTIFICATIONS
    // ------------------------------------------------------------

    await _initializeLocalNotifications();

    // ------------------------------------------------------------
    // FCM PERMISSION
    // ------------------------------------------------------------

    await _requestPermission();

    // ------------------------------------------------------------
    // FOREGROUND MESSAGE
    // ------------------------------------------------------------

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ------------------------------------------------------------
    // BACKGROUND -> APP OPENED BY NOTIFICATION TAP
    // ------------------------------------------------------------

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // ------------------------------------------------------------
    // TERMINATED -> APP OPENED BY NOTIFICATION TAP
    // ------------------------------------------------------------

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      // Give Flutter a moment to finish building the app before
      // asking the navigation callback to open an order.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      await _handleNotificationTap(initialMessage);
    }

    // ------------------------------------------------------------
    // REGISTER CURRENT FCM TOKEN
    // ------------------------------------------------------------

    try {
      final token = await _messaging.getToken();

      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      // Notification registration failure must not prevent
      // the Admin app from starting.
      print('Admin push token registration failed: $e');
    }

    // ------------------------------------------------------------
    // TOKEN REFRESH
    // ------------------------------------------------------------

    _messaging.onTokenRefresh.listen((token) async {
      if (token.trim().isEmpty) {
        return;
      }

      try {
        await _registerToken(token);
      } catch (e) {
        print('Admin push token refresh failed: $e');
      }
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await adminLocalNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    final androidPlugin = adminLocalNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(adminNotificationChannel);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print(
      'Admin notification permission: '
      '${settings.authorizationStatus}',
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;

    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Devi Jewels';

    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'You have a new notification.';

    await adminLocalNotifications.show(
      id: _notificationId(message),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'devi_jewels_admin_orders',
          'Admin Orders',
          channelDescription: 'Notifications for new customer orders.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: _payloadFromMessage(message),
    );
  }

  int _notificationId(RemoteMessage message) {
    final messageId = message.messageId;

    if (messageId != null && messageId.isNotEmpty) {
      return messageId.hashCode & 0x7fffffff;
    }

    return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final payload = _payloadFromMessage(message);

    if (payload == null || payload.isEmpty) {
      return;
    }

    await _handlePayload(payload);
  }

  Future<void> _handleLocalNotificationTap(
    NotificationResponse response,
  ) async {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    await _handlePayload(payload);
  }

  Future<void> _handlePayload(String payload) async {
    if (!payload.startsWith('order:')) {
      return;
    }

    // IMPORTANT:
    // substring() requires an integer index.
    //
    // Correct:
    // payload.substring('order:'.length)
    final orderId = payload.substring('order:'.length).trim();

    if (orderId.isEmpty) {
      return;
    }

    final callback = onOrderNotificationTap;

    if (callback == null) {
      print(
        'Admin order notification tapped, '
        'but no navigation callback is configured.',
      );
      return;
    }

    await callback(orderId);
  }

  String? _payloadFromMessage(RemoteMessage message) {
    final type = message.data['type']?.toString();

    if (type == 'order') {
      final orderId = message.data['order_id']?.toString().trim();

      if (orderId != null && orderId.isNotEmpty) {
        return 'order:$orderId';
      }
    }

    return null;
  }

  Future<void> _registerToken(String token) async {
    if (_adminKey.trim().isEmpty) {
      throw Exception(
        'Notification admin key is not configured. '
        'Run the Admin app with '
        '--dart-define=NOTIFICATION_ADMIN_KEY=...',
      );
    }

    final response = await supabase.functions.invoke(
      'register-admin-push-token',
      headers: {'x-notification-admin-key': _adminKey},
      body: {'token': token, 'platform': 'android'},
    );

    final data = response.data;

    if (data is! Map) {
      throw Exception(
        'Invalid response from admin push '
        'registration service.',
      );
    }

    final result = Map<String, dynamic>.from(data);

    if (result['success'] != true) {
      throw Exception(
        result['error']?.toString() ?? 'Unable to register admin push token.',
      );
    }

    print('Admin FCM token registered successfully.');
  }
}
