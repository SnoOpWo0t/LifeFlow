import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/scan_result.dart';

class ScanException implements Exception {
  final String message;
  const ScanException(this.message);
  @override
  String toString() => message;
}

/// Sends a photo to the API's AI reader. The Gemini key lives on the server.
class ScanRepository {
  final ApiClient _apiClient;
  ScanRepository(this._apiClient);

  /// [target]: 'money' (receipts, notes -> expenses/income) or 'wishlist'.
  Future<ScanResult> scan(List<int> bytes, String target) async {
    final mimeType = imageMimeType(bytes);
    if (mimeType == null) {
      throw const ScanException('Choose a JPEG, PNG, WebP or HEIC photo.');
    }
    try {
      final response = await _apiClient.dio.post(
        '/scan',
        data: {
          'image': base64Encode(bytes),
          'mime_type': mimeType,
          'target': target,
        },
        // Reading a photo can take up to a minute.
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 75),
        ),
      );
      return ScanResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message'] : null;
      if (message is String && message.isNotEmpty) throw ScanException(message);
      throw ScanException(
        e.type == DioExceptionType.receiveTimeout
            ? 'The photo reader took too long. Try again.'
            : "Couldn't reach the photo reader. Check your connection.",
      );
    } on FormatException {
      throw const ScanException(
        "The photo reader's answer couldn't be read. Try again.",
      );
    }
  }
}

final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  return ScanRepository(ref.watch(apiClientProvider));
});
