import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/cloudinary_config.dart';

class StorageService {
  Future<String?> uploadFile(
    File file, {
    void Function(double progress)? onProgress,
    String? folder,
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
          'https://api.cloudinary.com/v1_1/$cloudName/auto/upload', // 'auto' for any file type
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
        if (folder != null && folder.isNotEmpty) {
          request.fields['folder'] = folder;
        }
        request.files.add(multipartFile);

        final streamed = await request.send();
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          final data = json.decode(resp.body) as Map<String, dynamic>;
          // ensure we report completion
          try {
            if (onProgress != null) onProgress(1.0);
          } catch (_) {}
          return data['secure_url'] as String?;
        }
      } catch (e) {
        // print('Upload failed: $e');
        // fallback to null
      }
    }

    // If Cloudinary not configured or upload failed, return null
    return null;
  }
}
