import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor internet connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = false;
  final _streamController = StreamController<bool>.broadcast();

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Stream of connectivity changes
  Stream<bool> get onConnectivityChanged => _streamController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial status
    await checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      // Check if any connection type is available
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (hasConnection != _isOnline) {
        _isOnline = hasConnection;
        _streamController.add(_isOnline);

        debugPrint('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      }
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isOnline = false;
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _streamController.close();
  }
}
