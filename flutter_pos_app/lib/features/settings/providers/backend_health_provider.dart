import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';

/// Lightweight reachability check for Settings "Backend connection" row.
final settingsBackendReachableProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  try {
    final uri = ApiEndpoints.healthCheckUri();
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    final body = res.body;
    final okMarker = body.contains('POS Backend running') ||
        body.contains('POS backend is running') ||
        body.contains('"ok":true');
    return res.statusCode == 200 && okMarker;
  } catch (_) {
    return false;
  }
});
