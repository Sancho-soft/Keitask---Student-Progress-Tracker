import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AttachmentHelper {
  static Future<void> openAttachment(BuildContext context, String url) async {
    if (url.isEmpty) {
      _showError(context, 'Cannot open file: Invalid URL');
      return;
    }

    // Clean URL for access (remove custom query params like originalName)
    final uri = Uri.parse(url);
    final Map<String, dynamic> newParams = Map.from(uri.queryParameters);
    newParams.remove('originalName');

    // Reconstruct URL.
    // uri.replace(queryParameters: newParams) might add a trailing '?' if map is empty but not null?
    // Actually, Uri.toString() handles it well usually.
    // But let's be explicitly safe: if newParams is empty, clear the query entirely.
    final cleanUri = newParams.isEmpty
        ? uri.replace(queryParameters: {}) // This should remove the '?'
        : uri.replace(queryParameters: newParams);

    final cleanUrl = cleanUri.toString();

    final lowerUrl = cleanUrl.toLowerCase().split('?').first;
    debugPrint('Opening Attachment: $cleanUrl');

    // 1. Google Docs Viewer Types (DOC, DOCX, XLS, XLSX, PPT, PPTX)
    // NOTE: PDF removed from here. Direct launch is more reliable than Google Docs Viewer for PDFs.
    if (lowerUrl.endsWith('.doc') ||
        lowerUrl.endsWith('.docx') ||
        lowerUrl.endsWith('.xls') ||
        lowerUrl.endsWith('.xlsx') ||
        lowerUrl.endsWith('.ppt') ||
        lowerUrl.endsWith('.pptx')) {
      final googleDocsUrl =
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(cleanUrl)}';

      if (await canLaunchUrl(Uri.parse(googleDocsUrl))) {
        await launchUrl(
          Uri.parse(googleDocsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!context.mounted) return;
        _showError(context, 'Could not open Google Docs Viewer');
      }
      return;
    }

    // 2. PDF Handling
    if (lowerUrl.endsWith('.pdf')) {
      // Direct launch is often more reliable on mobile devices than Google Docs Viewer
      // especially if the URL has authentication tokens or specific headers.
      if (await canLaunchUrl(Uri.parse(cleanUrl))) {
        await launchUrl(
          Uri.parse(cleanUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (!context.mounted) return;
      _showError(context, 'Could not open PDF file.');
      return;
    }

    // 3. Images (Native Preview) - Keep original URL if it works, or clean?
    // Images usually work with params unless signed. Let's use cleanUrl.
    if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.webp')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _FullScreenImage(url: cleanUrl)),
      );
      return;
    }

    // 4. Fallback: Standard Download/Browser Open
    if (await canLaunchUrl(Uri.parse(cleanUrl))) {
      await launchUrl(
        Uri.parse(cleanUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (!context.mounted) return;
      _showError(context, 'Could not launch file');
    }
  }

  static Future<void> downloadAttachment(
    BuildContext context,
    String url,
  ) async {
    final uri = Uri.parse(url);
    final Map<String, dynamic> newParams = Map.from(uri.queryParameters);
    newParams.remove('originalName');
    final cleanUri = newParams.isEmpty
        ? uri.replace(queryParameters: {})
        : uri.replace(queryParameters: newParams);
    final cleanUrl = cleanUri.toString();

    debugPrint('Downloading Attachment: $cleanUrl');

    if (await canLaunchUrl(Uri.parse(cleanUrl))) {
      await launchUrl(
        Uri.parse(cleanUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (!context.mounted) return;
      _showError(context, 'Could not download file');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white, size: 48),
                  SizedBox(height: 16),
                  Text('Image Error', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
