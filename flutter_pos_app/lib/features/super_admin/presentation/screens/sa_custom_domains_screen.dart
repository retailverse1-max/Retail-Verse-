import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

class SaCustomDomainsScreen extends ConsumerStatefulWidget {
  const SaCustomDomainsScreen({super.key});

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider).user;
      final role = user?['role']?.toString() ?? '';
      final isAdmin = role == 'admin' || role == 'client';

      List<Map<String, dynamic>> businesses = [];
      try {
        if (isAdmin) {
          final clientId = user?['clientId']?.toString() ?? user?['businessId']?.toString() ?? 'admin_store_id';
          businesses = [{'id': clientId, 'businessName': 'Your Store (Current)'}];
        } else {
          businesses = await _superAdminService.listBusinesses();
        }
      } catch (e) {
        if (mounted) _showError('Could not load businesses: $e');
      }

      final domains = await _superAdminService.listCustomDomains();
      if (mounted) {
        setState(() {
          _businesses = businesses;
          _domains = domains;
          if (_businesses.isNotEmpty && _selectedBusinessId == null) {
            _selectedBusinessId = _businesses.first['id']?.toString() ?? _businesses.first['_id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) _showError('Failed to load data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _addDomain() async {
    if (_selectedBusinessId == null) {
      _showError('Please select a business');
      return;
    }
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      _showError('Please enter a domain');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final newDomain = await _superAdminService.addCustomDomain(
        businessId: _selectedBusinessId!,
        domain: domain,
      );
      _domainController.clear();
      _showSuccess('Domain added. Please configure DNS.');
      setState(() => _lastAddedDomain = newDomain);
      await _loadData();
    } catch (e) {
      _showError('Failed: $e');
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
        leading: (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton(
                  onPressed: () => saScaffoldNavigationKey.currentState?.openDrawer(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary, size: 20),
                  ),
                ),
              )
            : ResponsiveMenuButton(
                isSuperAdmin: ref.watch(authProvider).user?['role'] == 'super_admin',
              ),
        title: Text('Domain Manager', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    _buildSimpleAddCard(),
                    if (_lastAddedDomain != null) ...[
                      const SizedBox(height: 24),
                      _buildDnsInstructionCard(_lastAddedDomain!),
                    ],
                    const SizedBox(height: 32),
                    Text('YOUR DOMAINS', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
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
          Text('Connect New Domain', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          _buildLargeDropdown(),
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
                : const Text('CONNECT DOMAIN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeDropdown() {
    if (_businesses.isEmpty) {
      return DropdownButtonFormField<String>(
        value: null,
        decoration: InputDecoration(
          labelText: 'Select Client',
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('No clients found', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)))
        ],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedBusinessId,
      decoration: InputDecoration(
        labelText: 'Select Client',
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        prefixIcon: const Icon(Icons.business_rounded, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
      items: _businesses.map((b) {
        final name = b['businessName']?.toString() ?? 'Unnamed';
        return DropdownMenuItem(value: b['id']?.toString() ?? b['_id']?.toString(), child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)));
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
        hintText: 'e.g. shop.brand.com',
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
                      Text(domain, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteDomain(id),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
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
                        onPressed: () => _verifyDomain(id),
                        style: FilledButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('VERIFY DNS', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  if (isVerified)
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _activateDomain(id),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('ACTIVATE DOMAIN', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _buildStatusBadge(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: color, size: 20)),
      ),
    );
  }

  Widget _buildDnsInstructionCard(Map<String, dynamic> domain) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Text('DNS Setup Guide', style: AppTypography.titleLarge.copyWith(color: Colors.blue.shade900, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Go to your domain provider (GoDaddy, etc.) and add this record:',
            style: AppTypography.bodySmall.copyWith(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildDnsRow('TYPE', 'CNAME'),
          const Divider(height: 24),
          _buildDnsRow('HOST / NAME', domain['dnsName'] ?? 'store'),
          const Divider(height: 24),
          _buildDnsRow('VALUE / POINTS TO', domain['dnsValue'] ?? 'app.retailverse.in', canCopy: true),
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
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ],
        ),
        if (canCopy)
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _showSuccess('Value copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.blue),
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900)),
    );
  }

  Future<void> _verifyDomain(String id) async {
    try {
      await _superAdminService.verifyCustomDomain(id);
      _showSuccess('Domain verified successfully');
      _loadData();
    } catch (e) {
      _showError('Verification failed: $e');
    }
  }

  Future<void> _activateDomain(String id) async {
    try {
      await _superAdminService.activateCustomDomain(id);
      _showSuccess('Domain activated');
      _loadData();
    } catch (e) {
      _showError('Activation failed: $e');
    }
  }

  Future<void> _deleteDomain(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Domain?'),
        content: const Text('This will disconnect the domain from the business.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _superAdminService.deleteCustomDomain(id);
      _showSuccess('Domain deleted');
      _loadData();
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }
}
