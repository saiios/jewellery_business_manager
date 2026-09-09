import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  static const String _bucketName = 'jewellery-media';

  Future<String> uploadProductImage({
    required String productId,
    required File imageFile,
  }) async {
    final extension = _getFileExtension(imageFile.path);
    final filePath = 'products/$productId/image.$extension';

    await _supabase.storage
        .from(_bucketName)
        .upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }

  Future<String> uploadProductVideo({
    required String productId,
    required File videoFile,
  }) async {
    final extension = _getFileExtension(videoFile.path);
    final filePath = 'products/$productId/video.$extension';

    await _supabase.storage
        .from(_bucketName)
        .upload(
          filePath,
          videoFile,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: _getVideoContentType(extension),
          ),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }

  Future<void> deleteProductMedia(String? publicUrl) async {
    if (publicUrl == null || publicUrl.trim().isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(publicUrl);

      const bucketMarker = '/jewellery-media/';

      final pathIndex = uri.path.indexOf(bucketMarker);

      if (pathIndex == -1) {
        return;
      }

      final filePath = uri.path.substring(pathIndex + bucketMarker.length);

      if (filePath.isEmpty) {
        return;
      }

      await _supabase.storage.from(_bucketName).remove([filePath]);
    } catch (_) {
      // Do not block product updates if an old media file
      // cannot be removed.
    }
  }

  String _getFileExtension(String path) {
    final fileName = path.split('/').last;

    if (!fileName.contains('.')) {
      return 'jpg';
    }

    return fileName.split('.').last.toLowerCase();
  }

  String _getVideoContentType(String extension) {
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'mp4':
        return 'video/mp4';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }
}
