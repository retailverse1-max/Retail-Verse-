import 'dart:convert';
import 'dart:typed_data';

import '../constants/api_endpoints.dart';

/// Decodes `data:image/*;base64,...` payloads for [Image.memory]. Returns null if not a data URI or decode fails.
Uint8List? decodeDataImageBytes(String? pathOrUrl) {
  final s = pathOrUrl?.trim();
  if (s == null || s.isEmpty) return null;
  if (!s.startsWith('data:image')) return null;
  final comma = s.indexOf(',');
  if (comma < 0 || comma >= s.length - 1) return null;
  final header = s.substring(0, comma);
  final payload = s.substring(comma + 1);
  if (!header.contains(';base64')) return null;
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

/// Raw base64 in DB (no `data:image/...;base64,` prefix). Heuristic: long, path-like excluded.
Uint8List? decodeBareBase64ProductImageBytes(String? raw) {
  final s = raw?.trim();
  if (s == null || s.length < 80) return null;
  if (s.startsWith('data:') ||
      s.startsWith('http://') ||
      s.startsWith('https://') ||
      s.startsWith('/') ||
      s.startsWith('file:')) {
    return null;
  }
  final compact = s.replaceAll(RegExp(r'\s'), '');
  if (compact.length < 80) return null;
  if (!RegExp(r'^[A-Za-z0-9+/]+=*$').hasMatch(compact)) return null;
  try {
    return base64Decode(compact);
  } catch (_) {
    return null;
  }
}

bool _isLoopbackHost(String host) {
  final h = host.toLowerCase();
  return h == 'localhost' ||
      h == '127.0.0.1' ||
      h == '0.0.0.0' ||
      h == '::1' ||
      h == '10.0.2.2';
}

/// Aligns stored paths with [backend/utils/serializeProduct.js] before joining to [ApiEndpoints.serverOrigin].
String _normalizeStoredImageRef(String input) {
  var s = input.trim();
  if (s.isEmpty || s == 'null') return s;
  if (s.startsWith('data:image') || s.startsWith('//')) return s;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  if (!s.startsWith('/')) s = '/$s';
  if (s.startsWith('/api/uploads/')) {
    s = s.replaceFirst('/api', '');
  }
  if (s.startsWith('/products/') && !s.startsWith('/uploads/')) {
    s = '/uploads$s';
  }
  final secondSlash = s.indexOf('/', 1);
  if (secondSlash < 0 &&
      RegExp(r'\.(png|jpe?g|webp|gif|bmp)$', caseSensitive: false).hasMatch(s)) {
    s = '/uploads/products$s';
  }
  return s;
}

bool _sameOriginAsApi(Uri imageUri) {
  final api = Uri.parse(ApiEndpoints.baseUrl);
  if (imageUri.host.isEmpty) return false;
  return imageUri.scheme == api.scheme &&
      imageUri.host == api.host &&
      imageUri.port == api.port;
}

/// Whether to attach Bearer token (skip for same-origin `/uploads/` — avoids odd static middleware behavior).
bool shouldSendAuthForProductImageUrl(String resolvedUrl) {
  final uri = Uri.tryParse(resolvedUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return true;
  if (!uri.path.startsWith('/uploads/')) return true;
  return !_sameOriginAsApi(uri);
}

/// Strips trailing slashes from [ApiEndpoints.serverOrigin] and joins [absolutePathOrQuery]
/// (must start with `/` or `uploads/...`) — avoids [Uri.resolve] edge cases on some devices.
String _joinServerOrigin(String absolutePathOrQuery) {
  var origin = ApiEndpoints.serverOrigin.trim();
  while (origin.endsWith('/')) {
    origin = origin.substring(0, origin.length - 1);
  }
  var rest = absolutePathOrQuery.trim();
  if (rest.isEmpty) return origin;
  if (rest.startsWith('uploads/')) {
    rest = '/$rest';
  }
  if (!rest.startsWith('/')) {
    rest = '/$rest';
  }
  return '$origin$rest';
}

/// Same host + path as [ApiEndpoints.serverOrigin] + [uri] path/query (drops wrong LAN / loopback from DB).
String _imageUrlUsingApiOrigin(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  final q = uri.hasQuery ? '?${uri.query}' : '';
  return _joinServerOrigin('$path$q');
}

/// Turns `/uploads/products/...` or full `http(s)://...` into a loadable **network** image URL.
/// Does not prefix [data:image] URIs (use [decodeDataImageBytes] instead).
/// Protocol-relative URLs (`//host/...`) become `https://host/...`.
///
/// Rewrites:
/// - Any absolute URL whose path starts with `/uploads/` to use [ApiEndpoints.serverOrigin]
///   (fixes stale LAN IPs and `localhost` URLs saved in MongoDB).
/// - Loopback / emulator hosts (`localhost`, `127.0.0.1`, `10.0.2.2`, …) to the current API origin.
///
/// Uses [ApiEndpoints.serverOrigin] so paths align with static files on the API host (not under `/api`).
String? resolveProductImageUrl(String? pathOrUrl) {
  final raw = pathOrUrl?.trim();
  if (raw == null || raw.isEmpty) return null;
  // Local Flutter asset paths are not network URLs — avoid bad http://.../assets/... joins.
  if (raw.startsWith('assets/')) return null;
  if (raw.startsWith('data:image')) return null;
  if (raw.startsWith('//')) return 'https:$raw';
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return raw;
    var path = uri.path.replaceAll(RegExp(r'/+'), '/');
    if (path.startsWith('/api/uploads/')) {
      path = path.replaceFirst('/api', '');
    }
    final fixed = uri.replace(path: path);
    if (path.startsWith('/uploads/')) {
      return _imageUrlUsingApiOrigin(fixed);
    }
    if (_isLoopbackHost(fixed.host)) {
      return _imageUrlUsingApiOrigin(fixed);
    }
    return fixed.toString();
  }

  final s = _normalizeStoredImageRef(raw);
  if (s.isEmpty) return null;
  return _joinServerOrigin(s);
}
