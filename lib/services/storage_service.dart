import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/cloudinary_config.dart';

class StorageService {
  Future<String?> uploadFile(
    File file, {
    void Function(double progress)? onProgress,
    String? folder,
    String? resourceType, // 'auto', 'image', 'video', 'raw'
  }) async {
    // Try Cloudinary upload first. Configure these values accordingly.
    const envCloudName = String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: '',
    );
    const envUploadPreset = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: '',
    );

    final cloudName = envCloudName.isNotEmpty
        ? envCloudName
        : CloudinaryConfig.cloudName;
    final uploadPreset = envUploadPreset.isNotEmpty
        ? envUploadPreset
        : CloudinaryConfig.uploadPreset;

    // Only attempt upload when both values are provided and not the placeholder
    if (cloudName.isNotEmpty &&
        uploadPreset.isNotEmpty &&
        !cloudName.startsWith('PUT_') &&
        !uploadPreset.startsWith('PUT_')) {
      try {
        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/${resourceType ?? 'auto'}/upload',
        );

        final totalBytes = await file.length();
        int bytesSent = 0;

        // Create a byte stream that reports progress
        final stream = http.ByteStream(
          file.openRead().transform(
            StreamTransformer<List<int>, List<int>>.fromHandlers(
              handleData: (data, sink) {
                bytesSent += data.length;
                try {
                  if (onProgress != null && totalBytes > 0) {
                    final progress = bytesSent / totalBytes;
                    onProgress(progress.clamp(0.0, 1.0));
                  }
                } catch (_) {}
                sink.add(data);
              },
            ),
          ),
        );

        final multipartFile = http.MultipartFile(
          'file',
          stream,
          totalBytes,
          filename: file.path.split(Platform.pathSeparator).last,
        );

        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = uploadPreset;

        // Removed 'use_filename' and 'unique_filename' as they cause 400 errors with unsigned uploads
        // Cloudinary will generate a random public_id by default, which is safer.

        if (folder != null && folder.isNotEmpty) {
          request.fields['folder'] = folder;
        }

        // Explicitly request public access.
        // This attempts to override any "Private" default in the folder/preset.
        // REVERTED: This caused upload failures (400 Bad Request) on the user's preset.
        // try {
        //   request.fields['access_mode'] = 'public';
        // } catch (_) {}

        request.files.add(multipartFile);

        final streamed = await request.send();
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          debugPrint('Upload Success: ${data['secure_url']}'); // Log the URL
          // ensure we report completion
          try {
            if (onProgress != null) onProgress(1.0);
          } catch (_) {}
          return data['secure_url'] as String?;
        } else {
          debugPrint(
            'Cloudinary Upload Error: ${resp.statusCode} - ${resp.body}',
          );
        }
      } catch (e) {
        debugPrint('Upload failed: $e');
        // fallback to null
      }
    }

    // If Cloudinary not configured or upload failed, return null
    return null;
  }
}
