import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  static const String _bucketName = 'jewellery-media';

  /// Compresses an image before uploading.
  ///
  /// - Maximum dimension: 1200px
  /// - JPEG quality: 82
  /// - Output format: JPEG
  ///
  /// Returns the compressed temporary file.
  Future<File> _compressImage(File imageFile) async {
    final originalPath = imageFile.path;

    final tempPath =
        '${Directory.systemTemp.path}/compressed_${DateTime.now().microsecondsSinceEpoch}.jpg';

    final compressedBytes = await FlutterImageCompress.compressWithFile(
      originalPath,
      minWidth: 1200,
      minHeight: 1200,
      quality: 82,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressedBytes == null || compressedBytes.isEmpty) {
      // If compression fails, use the original file.
      return imageFile;
    }

    final compressedFile = File(tempPath);
    await compressedFile.writeAsBytes(compressedBytes, flush: true);

    return compressedFile;
  }

  Future<String> uploadProductImage({
    required String productId,
    required File imageFile,
  }) async {
    File? compressedFile;

    try {
      compressedFile = await _compressImage(imageFile);

      const extension = 'jpg';
      final filePath = 'products/$productId/image.$extension';

      await _supabase.storage
          .from(_bucketName)
          .upload(
            filePath,
            compressedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
    } finally {
      // Do not delete the original image.
      if (compressedFile != null && compressedFile.path != imageFile.path) {
        try {
          await compressedFile.delete();
        } catch (_) {
          // Ignore temporary file cleanup errors.
        }
      }
    }
  }

  Future<String> uploadAdditionalProductImage({
    required String productId,
    required File imageFile,
  }) async {
    File? compressedFile;

    try {
      compressedFile = await _compressImage(imageFile);

      final fileName = '${DateTime.now().microsecondsSinceEpoch}.jpg';

      final filePath = 'products/$productId/images/$fileName';

      await _supabase.storage
          .from(_bucketName)
          .upload(
            filePath,
            compressedFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
    } finally {
      if (compressedFile != null && compressedFile.path != imageFile.path) {
        try {
          await compressedFile.delete();
        } catch (_) {
          // Ignore temporary file cleanup errors.
        }
      }
    }
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

  String _getImageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
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
