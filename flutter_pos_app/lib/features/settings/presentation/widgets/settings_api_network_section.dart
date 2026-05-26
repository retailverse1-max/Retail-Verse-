import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/providers/api_config_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../pos/providers/order_providers.dart';
import '../../../pos/providers/product_providers.dart';
import '../../providers/backend_health_provider.dart';

/// API base URL, test/save — same behaviour as previous standalone Settings body.
class SettingsApiNetworkSection extends ConsumerStatefulWidget {
  const SettingsApiNetworkSection({super.key});

  @override
  ConsumerState<SettingsApiNetworkSection> createState() =>
      _SettingsApiNetworkSectionState();
}

class _SettingsApiNetworkSectionState
    extends ConsumerState<SettingsApiNetworkSection> {
  late final TextEditingController _urlController;
  bool _testing = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiEndpoints.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Uri _healthUriForApiBase(String apiBase) {
    final u = Uri.parse(apiBase);
    return Uri(scheme: u.scheme, host: u.host, port: u.port, path: '/');
  }

  String _normalizeTypedBase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return ApiEndpoints.baseUrl;
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (!s.endsWith('/api')) s = '$s/api';
    return s;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final apiBase = _normalizeTypedBase(_urlController.text);
      final uri = _healthUriForApiBase(apiBase);
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final b = response.body;
      final ok = response.statusCode == 200 &&
          (b.contains('POS Backend running') ||
              b.contains('POS backend is running') ||
              b.contains('"ok":true'));
      setState(() {
        _testMessage = ok
            ? 'Reachable: $uri'
            : 'HTTP ${response.statusCode} — check URL';
      });
    } catch (e) {
      setState(() => _testMessage = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
      ref.invalidate(settingsBackendReachableProvider);
    }
  }

  Future<void> _saveUrl() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      await ApiEndpoints.setPersistedBaseUrl(null);
    } else {
      await ApiEndpoints.setPersistedBaseUrl(raw);
    }
    ref.read(apiConfigRefreshProvider.notifier).state++;
    ref.invalidate(dashboardRemoteDataSourceProvider);
    ref.invalidate(productRepositoryProvider);
    ref.invalidate(orderRemoteDataSourceProvider);
    invalidateAllDashboardProviders(ref);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('API: ${ApiEndpoints.baseUrl}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    ref.invalidate(settingsBackendReachableProvider);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9AA5B1)
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Point the app to your Node backend (port 5000). Physical devices need your computer’s LAN IP.',
          style: AppTypography.bodySmall.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'API base URL',
            hintText: 'https://app-backend-je91.onrender.com/api',
            isDense: true,
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded, size: 20),
              label: Text(_testing ? 'Testing…' : 'Test'),
            ),
            OutlinedButton.icon(
              onPressed: _saveUrl,
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text('Save'),
            ),
            TextButton(
              onPressed: () async {
                await ApiEndpoints.setPersistedBaseUrl(null);
                ref.read(apiConfigRefreshProvider.notifier).state++;
                ref.invalidate(dashboardRemoteDataSourceProvider);
                ref.invalidate(productRepositoryProvider);
                ref.invalidate(orderRemoteDataSourceProvider);
                invalidateAllDashboardProviders(ref);
                if (mounted) {
                  _urlController.text = ApiEndpoints.baseUrl;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reset to automatic URL'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                ref.invalidate(settingsBackendReachableProvider);
              },
              child: const Text('Reset default'),
            ),
          ],
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _testMessage!,
            style: AppTypography.bodySmall.copyWith(
              color: _testMessage!.startsWith('Reachable')
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Active: ${ApiEndpoints.baseUrl}',
          style: AppTypography.labelSmall.copyWith(color: muted),
        ),
      ],
    );
  }
}
