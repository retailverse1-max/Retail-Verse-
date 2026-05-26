import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global Error Detector - Catches and logs all Flutter errors
///
/// This utility helps you debug issues on physical devices by:
/// - Catching all uncaught exceptions
/// - Logging detailed error information
/// - Showing user-friendly error messages
/// - Saving error logs for analysis
class ErrorDetector {
  ErrorDetector._();

  /// Initialize global error handlers
  /// Call this in main() before runApp()
  static void initialize() {
    // Override Flutter's default error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Catch all async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true; // Error handled
    };
  }

  /// Handle Flutter framework errors
  static void _handleFlutterError(FlutterErrorDetails details) {
    final error = details.exception;
    final stack = details.stack;

    // Log with nice formatting
    _logError('FLUTTER FRAMEWORK ERROR', error, stack);

    // In debug mode, print more details
    if (kDebugMode) {
      debugPrint('═══ ERROR DETAILS ═══');
      debugPrint('Library: ${details.library}');
      debugPrint('Context: ${details.context}');
      debugPrint('Silent: ${details.silent}');
      debugPrint('═══════════════════════');
    }

    // Show error UI if needed
    if (kDebugMode) {
      _showErrorInUI('Framework Error: ${error.toString()}', details);
    }
  }

  /// Handle async errors (from Futures, Streams, etc.)
  static void _handleAsyncError(Object error, StackTrace stack) {
    _logError('ASYNC ERROR', error, stack);

    if (kDebugMode) {
      debugPrint('═══ ASYNC ERROR STACK ═══');
      debugPrint(stack.toString());
      debugPrint('══════════════════════════');
    }
  }

  /// Log error with consistent format
  static void _logError(String type, Object error, StackTrace? stack) {
    final timestamp = DateTime.now().toIso8601String();

    // Print with emoji and clear formatting
    print('''
╔═══════════════════════════════════════════════════════════╗
║                    ❌ $type DETECTED                       
╠═══════════════════════════════════════════════════════════╣
║  Time: $timestamp
╠───────────────────────────────────────────────────────────╢
║  Error Type: ${error.runtimeType}
║  Message: $error
╠───────────────────────────────────────────────────────────╢
║  Stack Trace:
║  ${stack?.toString().replaceAll('\n', '\n║  ') ?? 'No stack trace available'}
╚═══════════════════════════════════════════════════════════╝
''');

    // Also save to file for later analysis (optional)
    _saveErrorToFile(type, error, stack, timestamp);
  }

  /// Save error to file for offline analysis
  static Future<void> _saveErrorToFile(
    String type,
    Object error,
    StackTrace? stack,
    String timestamp,
  ) async {
    // TODO: Implement file saving if you want persistent logs
    // This would require path_provider and dart:io
    // For now, just log to console

    /*
    Example implementation:
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/error_logs.txt');
    await file.writeAsString('''
[$timestamp] $type
Error: $error
Stack: ${stack?.toString()}
═══════════════════════════════\n
    ''', mode: FileMode.append);
    */
  }

  /// Show error in UI (debug mode only)
  static void _showErrorInUI(String message, FlutterErrorDetails? details) {
    // This would require a BuildContext to show a dialog/snackbar
    // For now, we rely on console logging
    // You can integrate this with a notification system
  }

  /// Report custom errors from your code
  static void reportError(String context, Object error, [StackTrace? stack]) {
    _logError('CUSTOM ERROR - $context', error, stack ?? StackTrace.current);
  }

  /// Report caught exceptions with context
  static void reportException(
    String action,
    Exception exception, [
    StackTrace? stack,
  ]) {
    _logError('EXCEPTION IN $action', exception, stack ?? StackTrace.current);
  }

  /// Safe wrapper for async operations - catches and logs errors
  static Future<T?> safeAsync<T>({
    required Future<T> Function() operation,
    String? context,
    T? defaultValue,
    Function(Object error, StackTrace stack)? onError,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      final errorContext = context ?? 'Unknown async operation';
      reportError(errorContext, e, stack);

      if (onError != null) {
        onError(e, stack);
      }

      return defaultValue;
    }
  }

  /// Safe wrapper for sync operations - catches and logs errors
  static T? safeSync<T>({
    required T Function() operation,
    String? context,
    T? defaultValue,
    Function(Object error, StackTrace stack)? onError,
  }) {
    try {
      return operation();
    } catch (e, stack) {
      final errorContext = context ?? 'Unknown sync operation';
      reportError(errorContext, e, stack);

      if (onError != null) {
        onError(e, stack);
      }

      return defaultValue;
    }
  }

  /// Get common error solutions
  static String? getSuggestedSolution(Object error) {
    final errorMessage = error.toString().toLowerCase();

    // Network errors
    if (errorMessage.contains('socket') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('network')) {
      return '💡 Check network connection and backend server status';
    }

    // Null errors
    if (errorMessage.contains('null') || errorMessage.contains('checked')) {
      return '💡 Enable null safety or add null checks';
    }

    // Type errors
    if (errorMessage.contains('type') || errorMessage.contains('cast')) {
      return '💡 Check data types and avoid invalid type casting';
    }

    // Render overflow errors
    if (errorMessage.contains('overflow') || errorMessage.contains('render')) {
      return '💡 Use SingleChildScrollView or constrain widget sizes';
    }

    // Asset loading errors
    if (errorMessage.contains('asset') || errorMessage.contains('image')) {
      return '💡 Verify asset exists in pubspec.yaml and file path is correct';
    }

    // Permission errors
    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied')) {
      return '💡 Check app permissions in AndroidManifest.xml / Info.plist';
    }

    return null; // No specific suggestion
  }
}

/// Widget wrapper that catches and logs build errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String label;
  final Widget? errorWidget;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.label,
    this.errorWidget,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return _ErrorCatcher(
      label: widget.label,
      onError: (error, stack) {
        setState(() {
          _hasError = true;
          _error = error;
        });
      },
      child: widget.child,
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 40),
          const SizedBox(height: 12),
          Text(
            'Error in ${widget.label}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error?.toString() ?? 'Unknown error',
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _error = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Internal widget that catches build errors
class _ErrorCatcher extends StatelessWidget {
  final Widget child;
  final String label;
  final Function(Object error, StackTrace stack) onError;

  const _ErrorCatcher({
    required this.child,
    required this.label,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (e, stack) {
      ErrorDetector.reportError('ErrorBoundary: $label', e, stack);
      onError(e, stack);
      return const SizedBox.shrink();
    }
  }
}
