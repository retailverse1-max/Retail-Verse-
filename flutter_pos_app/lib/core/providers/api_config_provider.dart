import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment after changing [ApiEndpoints] so Riverpod rebuilds HTTP clients.
final apiConfigRefreshProvider = StateProvider<int>((ref) => 0);
