import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _adminKey = String.fromEnvironment(
    'NOTIFICATION_ADMIN_KEY',
    defaultValue: '',
  );

  Future<NotificationSendResult> sendProductNotification({
    required String productId,
    required String itemCode,
    required String title,
    required String message,
  }) async {
    if (_adminKey.trim().isEmpty) {
      throw Exception(
        'Notification admin key is not configured. '
        'Run the app with '
        '--dart-define=NOTIFICATION_ADMIN_KEY=...',
      );
    }

    final response = await _supabase.functions.invoke(
      'send-product-notification',
      headers: {'x-notification-admin-key': _adminKey},
      body: {
        'product_id': productId,
        'item_code': itemCode,
        'title': title,
        'message': message,
      },
    );

    final data = response.data;

    if (data is! Map) {
      throw Exception('Invalid response from notification service.');
    }

    final success = data['success'] == true;

    final recipientCount = (data['recipient_count'] as num?)?.toInt() ?? 0;

    final successCount = (data['success_count'] as num?)?.toInt() ?? 0;

    final failedCount = (data['failed_count'] as num?)?.toInt() ?? 0;

    final status = data['status']?.toString();

    final notificationId = data['notification_id']?.toString();

    if (!success && recipientCount > 0) {
      throw Exception(
        'Notification failed. '
        'Successful: $successCount, '
        'Failed: $failedCount'
        '${status == null ? '' : ', status: $status'}.',
      );
    }

    return NotificationSendResult(
      notificationId: notificationId,
      recipientCount: recipientCount,
      successCount: successCount,
      failedCount: failedCount,
      status: status,
      success: success,
    );
  }
}

class NotificationSendResult {
  final String? notificationId;
  final int recipientCount;
  final int successCount;
  final int failedCount;
  final String? status;
  final bool success;

  const NotificationSendResult({
    required this.notificationId,
    required this.recipientCount,
    required this.successCount,
    required this.failedCount,
    required this.status,
    required this.success,
  });
}
