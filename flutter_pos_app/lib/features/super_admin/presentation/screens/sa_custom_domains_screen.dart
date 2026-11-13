import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/core/branding/app_branding.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/settings/providers/pos_settings_provider.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';
import 'package:retail_verse_pos/routes/app_router.dart';

class SaCustomDomainsScreen extends ConsumerStatefulWidget {
  final bool isSuperAdminRoute;
  const SaCustomDomainsScreen({super.key, this.isSuperAdminRoute = false});

  @override
  ConsumerState<SaCustomDomainsScreen> createState() => _SaCustomDomainsScreenState();
}

class _SaCustomDomainsScreenState extends ConsumerState<SaCustomDomainsScreen> {
  final _superAdminService = SuperAdminService();
  final _domainController = TextEditingController();

  List<Map<String, dynamic>> _businesses = [];
  List<Map<String, dynamic>> _domains = [];
  String? _selectedBusinessId;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _actionLoadingId;

  Map<String, dynamic>? _lastAddedDomain;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  String _resolveStoreName() {
    try {
      final posSettings = ref.read(posSettingsProvider);
      if (posSettings.storeName.trim().isNotEmpty &&
          posSettings.storeName.trim().toLowerCase() != 'retailverse' &&
          posSettings.storeName.trim().toLowerCase() != 'retail verse' &&
          posSettings.storeName.trim().toLowerCase() != 'my store') {
        return posSettings.storeName.trim();
      }
    } catch (_) {}

    final user = ref.read(authProvider).user;
    final userStore = (user?['shopName'] ?? user?['businessName'] ?? user?['companyName'])?.toString().trim();
    if (userStore != null && userStore.isNotEmpty && userStore.toLowerCase() != 'retailverse') {
      return userStore;
    }

    final userName = user?['name']?.toString().trim();
    if (userName != null && userName.isNotEmpty) {
      return "$userName's Store";
    }

    final branding = AppBranding.currentStoreName.trim();
    if (branding.isNotEmpty && branding.toLowerCase() != 'retailverse') {
      return branding;
    }

    return 'Store';
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!isSilent && _domains.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final user = ref.read(authProvider).user;
      final role = user?['role']?.toString().toLowerCase() ?? '';
      final isSuperAdmin = role == 'super_admin';

      final userStoreName = _resolveStoreName();
      final userClientId = user?['clientId']?.toString() ??
          user?['businessId']?.toString() ??
          user?['id']?.toString() ??
          'admin_store_id';

      List<Map<String, dynamic>> businesses = [];
      if (isSuperAdmin) {
        try {
          businesses = await _superAdminService.listBusinesses();
        } catch (_) {}
      }

      if (businesses.isEmpty) {
        businesses = [{'id': userClientId, 'businessName': userStoreName}];
      }

      final domains = await _superAdminService.listCustomDomains();
      if (mounted) {
        setState(() {
          _businesses = businesses;
          // If we had a recently added domain, merge it into domains if missing
          if (_lastAddedDomain != null) {
            final lastId = _lastAddedDomain!['id']?.toString() ?? _lastAddedDomain!['_id']?.toString();
            final lastDomName = (_lastAddedDomain!['domain'] ?? _lastAddedDomain!['domainName'])?.toString().toLowerCase();
            final exists = domains.any((d) =>
                (d['id']?.toString() ?? d['_id']?.toString()) == lastId ||
                (d['domain'] ?? d['domainName'])?.toString().toLowerCase() == lastDomName);
            if (!exists && lastDomName != null && lastDomName.isNotEmpty) {
              domains.insert(0, _lastAddedDomain!);
            }
          }
          _domains = domains;
          // Keep DNS instructions accessible: if not selected, pick first domain
          if (_domains.isNotEmpty && _lastAddedDomain == null) {
            _lastAddedDomain = _domains.first;
          }
          _selectedBusinessId = isSuperAdmin
              ? (_selectedBusinessId ?? businesses.first['id']?.toString() ?? businesses.first['_id']?.toString())
              : userClientId;
        });
      }
    } catch (e) {
      if (mounted) _showError('Failed to load data: $e');
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _showError(String rawMessage) {
    String message = rawMessage;
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('offline')) {
      message = 'You are offline. Please check your internet connection.';
    } else if (lower.contains('11000') ||
        lower.contains('already registered') ||
        lower.contains('already exists')) {
      message = 'This domain is already registered. Please enter a different domain.';
    } else if (lower.contains('not found') ||
        lower.contains('/api/') ||
        lower.contains('404')) {
      message = 'Domain service is currently unavailable. Please try again.';
    } else if (lower.contains('invalid domain') ||
        lower.contains('enter correct domain') ||
        lower.contains('domain name is required') ||
        lower.contains('domain is required') ||
        lower.contains('correct domain name')) {
      message = 'Please enter a valid domain name (e.g. daizyhome.com or shop.daizyhome.com)';
    } else {
      message = message
          .replaceAll('Exception:', '')
          .replaceAll('ApiException:', '')
          .trim();
      if (message.startsWith('Failed: ')) {
        message = message.substring(8).trim();
      }
    }

    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(message),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(message),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addDomain() async {
    // 1. Sanitize domain input
    String domain = _domainController.text.trim().toLowerCase();
    domain = domain.replaceFirst(RegExp(r'^https?:\/\/'), '');
    if (domain.contains('/')) {
      domain = domain.substring(0, domain.indexOf('/'));
    }
    if (domain.contains('?')) {
      domain = domain.substring(0, domain.indexOf('?'));
    }
    domain = domain.trim();

    // 2. Validate domain format (e.g. store.com, my-shop.co.in)
    final domainRegex = RegExp(
      r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$',
      caseSensitive: false,
    );

    if (domain.isEmpty || !domainRegex.hasMatch(domain)) {
      _showError('Please enter a correct domain name (e.g. yourstore.com or shop.yourstore.in)');
      return;
    }

    // 3. Business ID
    final user = ref.read(authProvider).user;
    final role = user?['role']?.toString().toLowerCase() ?? '';
    final isSuperAdmin = role == 'super_admin';

    final targetBusinessId = isSuperAdmin
        ? (_selectedBusinessId ?? user?['clientId']?.toString() ?? 'default_business')
        : (user?['clientId']?.toString() ??
            user?['businessId']?.toString() ??
            user?['id']?.toString() ??
            'admin_store_id');

    setState(() => _isSubmitting = true);
    try {
      final newDomain = await _superAdminService.addCustomDomain(
        businessId: targetBusinessId,
        domain: domain,
      );
      _domainController.clear();
      _showSuccess('Domain added! DNS record generated below.');
      setState(() {
        _lastAddedDomain = newDomain;
        final exists = _domains.any((d) =>
            (d['id']?.toString() ?? d['_id']?.toString() ?? d['domain']?.toString().toLowerCase()) ==
            (newDomain['id']?.toString() ?? newDomain['_id']?.toString() ?? domain.toLowerCase()));
        if (!exists) {
          _domains.insert(0, newDomain);
        }
      });
      await _loadData(isSilent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: () {
              if (widget.isSuperAdminRoute) {
                saScaffoldNavigationKey.currentState?.openDrawer();
              } else {
                scaffoldNavigationKey.currentState?.openDrawer();
              }
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardBorder.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ),
        title: Text('Domain Manager', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _isLoading && _domains.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: Colors.white,
                onRefresh: () => _loadData(isSilent: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
                  children: [
                    _buildSimpleAddCard(),
                    if (_lastAddedDomain != null) ...[
                      const SizedBox(height: 24),
                      _buildDnsInstructionCard(_lastAddedDomain!),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('YOUR DOMAINS', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
                        if (_domains.isNotEmpty)
                          Text('${_domains.length} linked', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_domains.isEmpty)
                      _buildEmptyState()
                    else
                      ..._domains.map((d) => _buildSimpleDomainCard(d)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSimpleAddCard() {
    final user = ref.watch(authProvider).user;
    final role = user?['role']?.toString().toLowerCase() ?? '';
    final isSuperAdmin = role == 'super_admin';
    final userStoreName = _resolveStoreName();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect New Domain', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Link your website domain (e.g. daizyhome.com) to your online store.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildStoreSelector(isSuperAdmin, userStoreName),
          const SizedBox(height: 16),
          _buildLargeTextField(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _addDomain,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: AppColors.primary,
              ),
              child: _isSubmitting 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('CONNECT DOMAIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector(bool isSuperAdmin, String adminStoreName) {
    if (!isSuperAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store / Business',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    adminStoreName,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Selected',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_businesses.isEmpty) {
      return DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Store / Business',
          helperText: 'Your store account',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('No store found', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)))
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedBusinessId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Client Store',
        helperText: 'Domain will connect to this store',
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
      items: _businesses.map((b) {
        final name = b['businessName']?.toString() ?? 'Unnamed';
        return DropdownMenuItem(
          value: b['id']?.toString() ?? b['_id']?.toString(),
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedBusinessId = v),
    );
  }

  Widget _buildLargeTextField() {
    return TextField(
      controller: _domainController,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: 'Domain Name',
        hintText: 'e.g. daizyhome.com',
        helperText: 'Enter your domain (e.g. daizyhome.com) without https://',
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  Widget _buildSimpleDomainCard(Map<String, dynamic> data) {
    final domain = data['domain'] ?? 'Unknown';
    final status = data['status']?.toString().toLowerCase() ?? 'pending';
    final id = data['id']?.toString() ?? data['_id']?.toString() ?? '';
    
    final isPending = status == 'pending';
    final isVerified = status == 'verified';
    final isActive = status == 'active';
    
    Color statusColor = AppColors.warning;
    if (isVerified) statusColor = Colors.blue;
    if (isActive) statusColor = AppColors.success;

    final isBusy = _actionLoadingId == id;
    final isShowingGuideForThis = _lastAddedDomain != null &&
        ((_lastAddedDomain!['id']?.toString() ?? _lastAddedDomain!['_id']?.toString()) == id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.language, color: statusColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(domain, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isShowingGuideForThis) {
                                    _lastAddedDomain = null;
                                  } else {
                                    _lastAddedDomain = data;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isShowingGuideForThis ? Icons.visibility_off_rounded : Icons.info_outline_rounded,
                                      size: 13,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isShowingGuideForThis ? 'Hide DNS' : 'View DNS',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Domain',
                  onPressed: isBusy ? null : () => _deleteDomain(id),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 26),
                ),
              ],
            ),
          ),
          if (!isActive) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (isPending)
                    Expanded(
                      child: FilledButton(
                        onPressed: isBusy ? null : () => _verifyDomain(id),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isBusy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('VERIFY DNS', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (isVerified)
                    Expanded(
                      child: FilledButton(
                        onPressed: isBusy ? null : () => _activateDomain(id),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isBusy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('ACTIVATE DOMAIN', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDnsInstructionCard(Map<String, dynamic> domain) {
    final domainName = domain['domain']?.toString() ?? 'your domain';
    final parts = domainName.split('.');
    final isSubdomain = parts.length > 2;
    final derivedHost = domain['dnsName']?.toString() ?? (isSubdomain ? parts.first : '@');
    final targetValue = domain['dnsValue']?.toString() ?? 'app.retailverse.in';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dns_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DNS Setup Guide',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Config for $domainName',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _lastAddedDomain = null),
                icon: const Icon(Icons.close_rounded, color: Colors.blueGrey, size: 22),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Go to your domain provider (GoDaddy, Namecheap, Cloudflare, etc.) and add this record:',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _buildDnsRow('TYPE', domain['dnsType']?.toString() ?? 'CNAME'),
          const Divider(height: 22),
          _buildDnsRow('HOST / NAME', derivedHost, canCopy: true),
          const Divider(height: 22),
          _buildDnsRow('VALUE / POINTS TO', targetValue, canCopy: true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSubdomain
                        ? 'For "$domainName", enter "$derivedHost" as the host name.'
                        : 'For root "$domainName", enter "@" (or your provider\'s apex host) pointing to $targetValue.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDnsRow(String label, String value, {bool canCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        if (canCopy)
          IconButton(
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _showSuccess('$label copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.blue, size: 20),
            style: IconButton.styleFrom(backgroundColor: Colors.white),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.link_off_rounded, size: 60, color: AppColors.textTertiary.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text('No domains linked yet', style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Future<void> _verifyDomain(String id) async {
    setState(() => _actionLoadingId = id);
    try {
      await _superAdminService.verifyCustomDomain(id);
      _showSuccess('Domain verified successfully');
      await _loadData(isSilent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  Future<void> _activateDomain(String id) async {
    setState(() => _actionLoadingId = id);
    try {
      await _superAdminService.activateCustomDomain(id);
      _showSuccess('Domain activated');
      await _loadData(isSilent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  Future<void> _deleteDomain(String id) async {
    final domainItem = _domains.firstWhere(
      (d) => (d['id']?.toString() ?? d['_id']?.toString()) == id,
      orElse: () => {},
    );
    final domainName = domainItem['domain'] ?? 'this domain';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Domain?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to disconnect "$domainName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Optimistic UI update: immediately remove from UI & clear DNS guide
    final backupDomains = List<Map<String, dynamic>>.from(_domains);
    final backupLastAdded = _lastAddedDomain;

    setState(() {
      _domains.removeWhere((d) => (d['id']?.toString() ?? d['_id']?.toString()) == id);
      if (_domains.isEmpty) {
        _lastAddedDomain = null;
      } else if (_lastAddedDomain != null) {
        final lastId = _lastAddedDomain!['id']?.toString() ?? _lastAddedDomain!['_id']?.toString();
        if (lastId == id) {
          _lastAddedDomain = null;
        }
      }
    });

    try {
      await _superAdminService.deleteCustomDomain(id);
      _showSuccess('Domain "$domainName" deleted successfully');
      await _loadData(isSilent: true);
    } catch (e) {
      // Revert optimistic update if API failed
      if (mounted) {
        setState(() {
          _domains = backupDomains;
          _lastAddedDomain = backupLastAdded;
        });
        _showError(e.toString());
      }
    }
  }
}
