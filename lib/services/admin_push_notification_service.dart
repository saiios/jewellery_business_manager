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

  // When the app is in the background, Android/Firebase
  // displays notification messages automatically.
  //
  // We don't perform Supabase/UI work here.
}

class AdminPushNotificationService {
  AdminPushNotificationService({required this.supabase});

  final SupabaseClient supabase;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _adminKey = String.fromEnvironment(
    'NOTIFICATION_ADMIN_KEY',
    defaultValue: '',
  );

  Future<void> initialize() async {
    // Admin push is Android-only for now.
    //
    // This avoids Firebase/APNs initialization requirements
    // on the older Mac/Xcode environment.
    if (!Platform.isAndroid) {
      return;
    }

    await _initializeLocalNotifications();

    await _requestPermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    try {
      final token = await _messaging.getToken();

      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      print('Admin initial push token registration failed: $e');
    }

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

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    print('Admin notification tapped: $payload');

    // We will connect this to CustomerOrderDetailsScreen
    // after the notification delivery itself is verified.
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
      id: message.hashCode,
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
  }
}
