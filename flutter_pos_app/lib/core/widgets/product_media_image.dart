import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/api_endpoints.dart';
import '../theme/app_colors.dart';
import '../utils/product_media_url.dart';

/// Renders a product image from a network URL, `data:image/...;base64,...`, or a server-relative path.
///
/// Uses [Image.network] (not disk cache) so failures are visible in logs and the same auth header
/// as `/api` can be sent — some deployments protect `/uploads` behind the same middleware.
class ProductMediaImage extends ConsumerWidget {
  const ProductMediaImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  final String? imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? rawUrl = imageUrl;

    // Fix incorrectly prefixed data URIs that came from backend as full URLs
    if (rawUrl != null && rawUrl.contains('data:image')) {
      final startIndex = rawUrl.indexOf('data:image');
      rawUrl = rawUrl.substring(startIndex);
    }

    Uint8List? memBytes;
    if (rawUrl != null && rawUrl.startsWith('data:image')) {
      try {
        final commaIdx = rawUrl.indexOf(',');
        if (commaIdx != -1) {
          final base64Str = rawUrl.substring(commaIdx + 1);
          memBytes = base64Decode(base64Str);
        }
      } catch (e) {
        debugPrint('Failed to decode base64: $e');
      }
    } else {
      memBytes = decodeDataImageBytes(rawUrl) ?? decodeBareBase64ProductImageBytes(rawUrl);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final h = height ?? (constraints.maxHeight.isFinite ? constraints.maxHeight : null);

        if (memBytes != null) {
          return Image.memory(
            memBytes,
            width: w,
            height: h,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => errorWidget ?? _defaultError(),
          );
        }

        String? resolved = resolveProductImageUrl(rawUrl);
        // Fallback resolution if it didn't work properly
        if (rawUrl != null) {
          if (rawUrl.startsWith('http')) {
            resolved = rawUrl;
          } else if (rawUrl.startsWith('/uploads')) {
            // strip /api from baseUrl if present to point to static uploads
            final backendHost = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api$'), '');
            resolved = '$backendHost$rawUrl';
          } else if (resolved == null) {
            resolved = rawUrl;
          }
        }

        if (resolved == null) {
          return errorWidget ?? _defaultError();
        }

        final token = ref.watch(authProvider.select((s) => s.token));
        final sendAuth =
            token != null &&
            token.isNotEmpty &&
            shouldSendAuthForProductImageUrl(resolved);
        // Same-origin `/uploads/...` static files: plain GET (no headers) loads reliably on
        // Android/iOS; custom headers can break some `express.static` / CDN setups.
        final Map<String, String>? headers = sendAuth
            ? <String, String>{
                'Accept': 'image/*,application/octet-stream;q=0.9,*/*;q=0.8',
                'User-Agent': 'RetailVerse-POS/1.0',
                'Authorization': 'Bearer $token',
              }
            : null;

        return Image.network(
          resolved,
          width: w,
          height: h,
          fit: fit,
          gaplessPlayback: true,
          headers: headers,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? _defaultPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              // Minimal debug print to avoid spam
              debugPrint('ProductMediaImage failed: $resolved');
            }
            return errorWidget ?? _defaultError();
          },
        );
      },
    );
  }

  Widget _defaultPlaceholder() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _defaultError() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
