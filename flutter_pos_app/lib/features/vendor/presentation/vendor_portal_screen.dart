import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/branding/app_branding.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../dashboard/presentation/widgets/dashboard_widgets.dart';
import '../../admin/data/vendor_service.dart';
import '../../admin/domain/models/vendor_model.dart';
import '../../auth/providers/auth_provider.dart';

class VendorPortalScreen extends ConsumerStatefulWidget {
  final String? initialVendorName;

  const VendorPortalScreen({
    super.key,
    this.initialVendorName,
  });

  @override
  ConsumerState<VendorPortalScreen> createState() => _VendorPortalScreenState();
}

class _VendorPortalScreenState extends ConsumerState<VendorPortalScreen> {
  final VendorService _vendorService = VendorService();

  String _currentVendorName = 'shreya';
  List<VendorProfile> _allVendors = [];
  bool _isVendorRole = false;

  bool _isLoading = true;
  String? _errorMessage;

  VendorPortalData? _portalData;
  int _activeTabIndex = 0; // 0: Overview, 1: Allocations, 2: Vendor Profile

  // Allocations tab filters & search
  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // All, Pending, Accepted, In Transit, Received
  final TextEditingController _searchController = TextEditingController();

  Timer? _liveSyncTimer;
  final Set<String> _seenOrderIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialVendorName != null && widget.initialVendorName!.isNotEmpty) {
      _currentVendorName = widget.initialVendorName!;
    }
    _loadAllVendorsAndData();

    // Start background poller so vendor gets instant phone notification when admin assigns units or stock drops <= 5
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _pollForNewAllocations();
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Live polling for newly assigned purchase orders or stock-low events
  Future<void> _pollForNewAllocations() async {
    try {
      final data = await _vendorService.getVendorPortalData(vendorName: _currentVendorName);
      bool hasNew = false;

      for (final req in data.requirements) {
        final key = '${req.orderId}_${req.units}';
        if (!_seenOrderIds.contains(req.orderId) && !_seenOrderIds.contains(key)) {
          _seenOrderIds.add(req.orderId);
          _seenOrderIds.add(key);
          hasNew = true;

          // Fire local phone notification like order placed successfully!
          final isManual = req.triggeredBy == 'manual_admin';
          await PushNotificationService.showLocalNotification(
            id: req.orderId.hashCode,
            title: isManual
                ? '📦 New Purchase Order Assigned: ${req.productName}'
                : '🚨 Stock Low Replenishment (Stock ≤ 5): ${req.productName}',
            body: 'Admin allocated ${req.units} units of ${req.productName} (PO #${req.orderId}) to your Vendor account.',
          );

          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New PO Assigned: #${req.orderId}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${req.units} units of ${req.productName} allocated to you',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      if (hasNew && mounted) {
        setState(() {
          _portalData = data;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAllVendorsAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authMap = await SessionService.readPersistedAuth();
      final persistedVendor = authMap[SessionService.persistedVendorNameKey];
      final persistedRole = authMap[SessionService.persistedUserRoleKey];
      final isVendor = persistedRole?.toLowerCase() == 'vendor';

      if (widget.initialVendorName != null && widget.initialVendorName!.isNotEmpty) {
        _currentVendorName = widget.initialVendorName!;
      } else if (persistedVendor != null && persistedVendor.isNotEmpty) {
        _currentVendorName = persistedVendor;
      }

      final vendors = await _vendorService.getVendors();
      final data = await _vendorService.getVendorPortalData(vendorName: _currentVendorName);

      for (final r in data.requirements) {
        _seenOrderIds.add(r.id);
        _seenOrderIds.add(r.orderId);
        _seenOrderIds.add('${r.orderId}_${r.units}');
      }

      if (mounted) {
        setState(() {
          _isVendorRole = isVendor;
          _allVendors = vendors;
          _portalData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to logout from Vendor Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showVendorAccountSheet() {
    final user = ref.read(authProvider).user;
    final userName = user?['name']?.toString() ?? _currentVendorName;
    final userEmail = user?['email']?.toString() ?? 'vendor@retailverse.com';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'V',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Text(
                          'VENDOR PARTNER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_allVendors.length > 1) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SWITCH VENDOR PORTAL VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allVendors.map((v) {
                  final isSelected = v.name.toLowerCase() == _currentVendorName.toLowerCase();
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _currentVendorName = v.name;
                      });
                      _loadAllVendorsAndData();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            v.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
              ),
              title: const Text('My Account & Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('View and edit personal account details', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/account');
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleLogout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
                label: const Text(
                  'Logout from Vendor Portal',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  backgroundColor: const Color(0xFFFFF1F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStatusUpdate(VendorRequirementItem item, String newStatus) async {
    // Instant optimistic update for silky-smooth response
    if (_portalData != null) {
      final updatedReqs = _portalData!.requirements.map((r) {
        if (r.id == item.id || r.orderId == item.orderId) {
          return r.copyWith(status: newStatus);
        }
        return r;
      }).toList();

      setState(() {
        _portalData = VendorPortalData(
          vendor: _portalData!.vendor,
          metrics: _portalData!.metrics,
          requirements: updatedReqs,
        );
      });
    }

    final success = await _vendorService.updateRequirementStatus(
      orderId: item.orderId,
      vendorName: item.vendorName ?? _currentVendorName,
      status: newStatus,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: success ? const Color(0xFF16A34A).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: success ? const Color(0xFF22C55E) : Colors.redAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      success ? 'Delivery Confirmed' : 'Update Failed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      success
                          ? '${item.orderId} successfully marked as $newStatus'
                          : 'Failed to update requirement status. Please try again.',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 3),
        ),
      );

      if (success) {
        _loadAllVendorsAndData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final isTablet = MediaQuery.of(context).size.width >= 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
          child: SafeArea(
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  const ResponsiveMenuButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Vendor Portal',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${AppBranding.getStoreName()} Partner Hub • Real-time Sync',
                                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Quick Vendor Profile Chip
                  InkWell(
                    onTap: _showVendorAccountSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundTertiary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              _currentVendorName.isNotEmpty
                                  ? _currentVendorName[0].toUpperCase()
                                  : 'V',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isTablet ? 120 : 65),
                            child: Text(
                              _currentVendorName,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Top bar action: Logout button
                  InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadAllVendorsAndData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Portal Banner Header styled with _buildSectionContainer
                            _buildBannerHeader(isDesktop, isTablet),
                            const SizedBox(height: 20),

                            // Tab Body
                            IndexedStack(
                              index: _activeTabIndex > 1 ? 0 : _activeTabIndex,
                              children: [
                                _buildOverviewTab(isDesktop, isTablet),
                                _buildAllocationsTab(isDesktop, isTablet),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  // ============================================================================
  // REUSABLE SECTION CONTAINER (Matching AddProductScreen Design Theme)
  // ============================================================================
  Widget _buildSectionContainer({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HERO BANNER & SUB-NAV TABS
  // -------------------------------------------------------------
  Widget _buildBannerHeader(bool isDesktop, bool isTablet) {
    final companyName = _portalData?.vendor.companyName.isNotEmpty == true
        ? _portalData!.vendor.companyName
        : '$_currentVendorName Supplies';

    final totalReqCount = _portalData?.requirements.length ?? 0;

    return _buildSectionContainer(
      icon: Icons.storefront_rounded,
      iconColor: AppColors.primary,
      title: companyName,
      subtitle: 'Replenishment allocations, read-receipt verification & dispatch milestones',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isVendorRole && _allVendors.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _allVendors.any((v) => v.name == _currentVendorName)
                      ? _currentVendorName
                      : _allVendors.first.name,
                  icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.primary),
                  isDense: true,
                  items: _allVendors.map((v) {
                    return DropdownMenuItem<String>(
                      value: v.name,
                      child: Text(
                        v.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentVendorName) {
                      setState(() {
                        _currentVendorName = val;
                      });
                      _loadAllVendorsAndData();
                    }
                  },
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 13, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Active Partner',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildTabPill(
            label: 'Overview',
            icon: Icons.dashboard_outlined,
            index: 0,
          ),
          _buildTabPill(
            label: 'Allocations ($totalReqCount)',
            icon: Icons.inventory_2_outlined,
            index: 1,
          ),
          InkWell(
            onTap: _loadAllVendorsAndData,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({required String label, required IconData icon, required int index}) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _activeTabIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: OVERVIEW TAB
  // -------------------------------------------------------------
  Widget _buildOverviewTab(bool isDesktop, bool isTablet) {
    final metrics = _portalData?.metrics ?? const VendorPortalMetrics();
    final requirements = _portalData?.requirements ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Summary Metrics Cards in ONE LINE (side-by-side, not stacked)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 950;

            final cardAllocated = _buildMetricCard(
              title: 'ALLOCATED UNITS',
              value: '${metrics.allocatedUnits} Units',
              subtitle: 'Across ${metrics.totalRequests} replenishment requests',
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF2563EB),
            );

            final cardAction = _buildMetricCard(
              title: 'ACTION REQUIRED',
              value: '${metrics.actionRequired}',
              subtitle: '${metrics.actionRequired} pending acceptance',
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFFF59E0B),
            );

            final cardInTransit = _buildMetricCard(
              title: 'IN TRANSIT / DISPATCHED',
              value: '${metrics.inTransit}',
              subtitle: 'Awaiting client receipt confirmation',
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFF8B5CF6),
            );

            final cardFulfilled = _buildMetricCard(
              title: 'FULFILLED & RECEIVED',
              value: '${metrics.fulfilled}',
              subtitle: 'Stock credited into warehouse',
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
            );

            if (isWide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cardAllocated),
                    const SizedBox(width: 14),
                    Expanded(child: cardAction),
                    const SizedBox(width: 14),
                    Expanded(child: cardInTransit),
                    const SizedBox(width: 14),
                    Expanded(child: cardFulfilled),
                  ],
                ),
              );
            }

            // On mobile / tablet: All cards in ONE LINE side-by-side horizontally
            final cardWidth = constraints.maxWidth < 600 ? 220.0 : 250.0;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: cardWidth, child: cardAllocated),
                    const SizedBox(width: 12),
                    SizedBox(width: cardWidth, child: cardAction),
                    const SizedBox(width: 12),
                    SizedBox(width: cardWidth, child: cardInTransit),
                    const SizedBox(width: 12),
                    SizedBox(width: cardWidth, child: cardFulfilled),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Latest Allocated Requirements Section Header
        _buildSectionContainer(
          icon: Icons.assignment_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Latest Allocated Requirements',
          subtitle: 'Low-stock replenishment orders published by administration',
          trailing: requirements.isNotEmpty
              ? OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _activeTabIndex = 1);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: Text('View All (${requirements.length})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
          child: requirements.isEmpty
              ? _buildEmptyRequirementsState()
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requirements.take(3).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = requirements[index];
                    return _buildRequirementCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequirementsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Requirements Allocated Yet',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When warehouse stock drops to low levels, admin split allocations\nassigned to you will appear here automatically.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: ALLOCATIONS TAB
  // -------------------------------------------------------------
  Widget _buildAllocationsTab(bool isDesktop, bool isTablet) {
    final allReqs = _portalData?.requirements ?? [];

    final filtered = allReqs.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.productSku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.orderId.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatusFilter == 'All' ||
          item.status.toLowerCase() == _selectedStatusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    return _buildSectionContainer(
      icon: Icons.format_list_bulleted_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'Procurement Requirements & Milestones',
      subtitle: 'Search allocations and update transit delivery milestones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Filter Row
          if (isDesktop || isTablet)
            Row(
              children: [
                SizedBox(
                  width: isDesktop ? 320 : 260,
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products, SKU, or PO...',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildStatusChip('All'),
                        const SizedBox(width: 8),
                        _buildStatusChip('Pending'),
                        const SizedBox(width: 8),
                        _buildStatusChip('Accepted'),
                        const SizedBox(width: 8),
                        _buildStatusChip('In Transit'),
                        const SizedBox(width: 8),
                        _buildStatusChip('Received'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products, SKU, or PO...',
                      hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatusChip('All'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Pending'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Accepted'),
                      const SizedBox(width: 8),
                      _buildStatusChip('In Transit'),
                      const SizedBox(width: 8),
                      _buildStatusChip('Received'),
                    ],
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Allocations List or Empty State
          if (filtered.isEmpty)
            _buildEmptyAllocationsState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _buildRequirementCard(filtered[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _selectedStatusFilter.toLowerCase() == label.toLowerCase();
    final allReqs = _portalData?.requirements ?? [];
    int count = 0;
    if (label == 'All') {
      count = allReqs.length;
    } else {
      count = allReqs.where((r) => r.status.toLowerCase() == label.toLowerCase()).length;
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedStatusFilter = label);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAllocationsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Allocated Requirements Found',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No procurement replenishment orders match the current filter criteria.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Single Requirement Card with interactive status buttons
  Widget _buildRequirementCard(VendorRequirementItem item) {
    Color statusColor = const Color(0xFFF59E0B);
    Color statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);

    if (item.status.toLowerCase().contains('transit') || item.status.toLowerCase().contains('dispatch')) {
      statusColor = const Color(0xFF8B5CF6);
      statusBg = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
    } else if (item.status.toLowerCase().contains('receive') || item.status.toLowerCase().contains('fulfill')) {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
    } else if (item.status.toLowerCase().contains('accept')) {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFF2563EB).withValues(alpha: 0.1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: PO Number + Status Chip + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      item.orderId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          item.vendorName != null && item.vendorName!.isNotEmpty
                              ? item.vendorName!
                              : _currentVendorName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.triggeredBy == 'auto_low_stock')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, size: 12, color: AppColors.error),
                          SizedBox(width: 2),
                          Text(
                            'Auto Low-Stock (<= 5)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Product & Units Information
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.productSku} • Total Batch: ${item.totalUnitsNeeded} Units',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${item.units} Units Allocated',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${DateFormat('dd MMM yyyy').format(item.targetDeliveryDate)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Milestone Action Buttons for Vendor
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${DateFormat('dd MMM, hh:mm a').format(item.createdAt)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (item.status == 'Pending')
                    ElevatedButton.icon(
                      onPressed: () => _handleStatusUpdate(item, 'Accepted'),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Accept Requirement'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  if (item.status == 'Accepted' || item.status == 'Pending')
                    OutlinedButton.icon(
                      onPressed: () => _handleStatusUpdate(item, 'In Transit'),
                      icon: const Icon(Icons.local_shipping_outlined, size: 14),
                      label: const Text('Mark In Transit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  if (item.status == 'In Transit')
                    OutlinedButton.icon(
                      onPressed: () => _handleStatusUpdate(item, 'Received'),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF0F172A)),
                      label: const Text('Mark Delivered'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  if (item.status == 'Received')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Marked Delivered',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text(
            'Failed to load Vendor Portal',
            style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Unknown error occurred.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllVendorsAndData,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
