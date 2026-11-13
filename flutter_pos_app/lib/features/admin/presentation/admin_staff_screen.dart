import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/admin_users_service.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final _svc = AdminUsersService();
  late Future<List<Map<String, dynamic>>> _f;
  String _searchQ = '';
  final _searchC = TextEditingController();

  static const _assignableRoles = ['cashier', 'admin', 'inventory', 'vendor', 'seo_manager', 'user'];

  static String _roleLabel(String r) {
    switch (r.toLowerCase()) {
      case 'cashier':
        return 'Cashier (POS & Billing)';
      case 'admin':
        return 'Store Admin (Management)';
      case 'inventory':
        return 'Inventory (Stock & Barcode)';
      case 'vendor':
        return 'Vendor (Supplier Portal)';
      case 'seo_manager':
        return 'SEO & Catalog Manager';
      case 'user':
        return 'Staff Member';
      default:
        return r.toUpperCase();
    }
  }

  @override
  void initState() {
    super.initState();
    _f = _svc.listUsers();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── MINIMALIST HEADER ──────────────────
          Container(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              boxShadow: AppColors.shadowSubtle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const ResponsiveMenuButton(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('User & Access', style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Manage store staff & roles', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _openCreateUserDialog,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 16),
                      label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TextField(
                    controller: _searchC,
                    onChanged: (v) => setState(() => _searchQ = v.trim().toLowerCase()),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  final errStr = snap.error.toString();
                  String cleanErr;
                  if (errStr.contains('SocketException') || errStr.contains('Connection') || errStr.contains('Failed host lookup')) {
                    cleanErr = 'You are offline or the server is unreachable. Please check your internet connection.';
                  } else if (errStr.contains('404') || errStr.contains('Not Found')) {
                    cleanErr = 'No staff found or server is updating. Tap retry or add your first member.';
                  } else if (errStr.contains('ApiException:')) {
                    cleanErr = errStr.split('ApiException:').last.trim();
                  } else {
                    cleanErr = errStr;
                  }
                  return _buildErrorState(cleanErr);
                }

                final users = snap.data ?? [];
                final filtered = users.where((u) {
                  final name = u['name']?.toString().toLowerCase() ?? '';
                  final email = u['email']?.toString().toLowerCase() ?? '';
                  return name.contains(_searchQ) || email.contains(_searchQ);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() => _f = _svc.listUsers()),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildModernUserCard(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernUserCard(Map<String, dynamic> u) {
    final name = u['name']?.toString() ?? '';
    final email = u['email']?.toString() ?? '';
    final role = u['role']?.toString() ?? 'user';
    final active = u['isActive'] == true;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {}, // Future detail view
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : 'Unnamed Member', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(email, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildRoleBadge(role, vendorName: u['vendorName']?.toString()),
                          _buildStatusIndicator(active),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildActionMenu(u, active, email),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, {String? vendorName}) {
    final isVendor = role.toLowerCase() == 'vendor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVendor ? const Color(0xFFFEF3C7) : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: isVendor ? Border.all(color: const Color(0xFFFDE68A)) : null,
      ),
      child: Text(
        isVendor && vendorName != null && vendorName.isNotEmpty
            ? 'VENDOR ($vendorName)'
            : role.toUpperCase(),
        style: TextStyle(
          color: isVendor ? const Color(0xFFB45309) : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? Colors.green : Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: active ? Colors.green : Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'ONLINE' : 'INACTIVE',
            style: TextStyle(color: active ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Map<String, dynamic> u, bool active, String email) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textTertiary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (v) => _handleMenuAction(v, u, active, email),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(active ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 18),
              const SizedBox(width: 12),
              Text(active ? 'Suspend Member' : 'Activate Member'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ..._assignableRoles.map((r) => PopupMenuItem(
          value: 'role:$r', 
          child: Text('Assign ${_roleLabel(r)}'),
        )),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete', 
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 12),
              Text('Remove Member', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(String v, Map<String, dynamic> u, bool active, String email) async {
    final id = u['_id']?.toString() ?? u['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      if (v == 'toggle') {
        await _svc.setUserActive(userId: id, isActive: !active);
      } else if (v == 'delete') {
        final confirm = await _showConfirmDialog(email);
        if (confirm != true) return;
        await _svc.deleteUser(userId: id);
      } else if (v.startsWith('role:')) {
        await _svc.updateUserRole(userId: id, role: v.substring(5));
      }
      if (mounted) {
        setState(() { _f = _svc.listUsers(); });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: const Text('Team updated successfully'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final clean = errStr.contains('SocketException') || errStr.contains('Failed host lookup')
            ? 'Network error. Please check your internet connection.'
            : (errStr.contains('ApiException:') ? errStr.split('ApiException:').last.trim() : errStr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(clean),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(String email) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Remove from Team?'),
        content: Text('Access for $email will be permanently revoked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateUserDialog() async {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final vendorNameC = TextEditingController();
    var role = _assignableRoles.first;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? dialogError;

    await showDialog<bool>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setLocal(() {
              isSubmitting = true;
              dialogError = null;
            });

            final name = nameC.text.trim();
            final email = emailC.text.trim().toLowerCase();
            final password = passC.text;
            final vendorName = role == 'vendor' ? vendorNameC.text.trim() : null;

            try {
              await _svc.createStaff(
                name: name,
                email: email,
                password: password,
                role: role,
                vendorName: vendorName,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
              }
              if (mounted) {
                setState(() {
                  _f = _svc.listUsers();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 3),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Member "$name" added successfully!',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            } catch (e) {
              final errStr = e.toString();
              String cleanErr;
              if (errStr.contains('11000') || errStr.toLowerCase().contains('duplicate') || errStr.contains('email_1')) {
                cleanErr = 'A member with this email already exists. Please use a different email.';
              } else if (errStr.toLowerCase().contains('limit reach') || errStr.toLowerCase().contains('upgrade')) {
                cleanErr = 'Member limit reached for current plan. Please upgrade to add more staff.';
              } else if (errStr.contains('SocketException') || errStr.contains('Failed host lookup') || errStr.contains('Connection')) {
                cleanErr = 'Network error. Please check your internet connection.';
              } else if (errStr.contains('ApiException:')) {
                cleanErr = errStr.split('ApiException:').last.trim();
              } else {
                cleanErr = errStr;
              }

              setLocal(() {
                isSubmitting = false;
                dialogError = cleanErr;
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Team Member',
                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildModernField(
                      nameC,
                      'Full Name',
                      Icons.person_rounded,
                      enabled: !isSubmitting,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter member name' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildModernField(
                      emailC,
                      'Work Email',
                      Icons.email_rounded,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter work email';
                        if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildModernField(
                      passC,
                      'Initial Password',
                      Icons.lock_rounded,
                      obscure: true,
                      enabled: !isSubmitting,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter initial password';
                        if (v.trim().length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: role,
                      isExpanded: true,
                      selectedItemBuilder: (ctx) => _assignableRoles
                          .map((r) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _roleLabel(r),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      items: _assignableRoles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  _roleLabel(r),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (v) {
                              if (v != null) {
                                setLocal(() => role = v);
                              }
                            },
                      decoration: InputDecoration(
                        labelText: 'Assigned Role',
                        prefixIcon: const Icon(Icons.shield_rounded, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
                      ),
                    ),
                    if (role == 'vendor') ...[
                      const SizedBox(height: 16),
                      _buildModernField(
                        vendorNameC,
                        'Vendor Business Name',
                        Icons.storefront_rounded,
                        hintText: 'e.g. Acme Supplies',
                        enabled: !isSubmitting,
                        validator: (v) {
                          if (role == 'vendor' && (v == null || v.trim().isEmpty)) {
                            return 'Please enter vendor business name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This vendor will access supplier portal to view assigned units and purchase orders.',
                        style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
    bool enabled = true,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), shape: BoxShape.circle),
              child: Icon(Icons.group_add_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No Team Members Yet', style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Add cashiers, managers, and vendors to streamline store operations and assign portal permissions.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add First Member'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final isNetwork = error.toLowerCase().contains('offline') ||
        error.toLowerCase().contains('internet') ||
        error.toLowerCase().contains('connection');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.people_outline_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNetwork ? 'Connection Lost' : 'Unable to Load Team',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                isNetwork
                    ? 'Please check your internet connection and try refreshing.'
                    : 'We could not sync your staff list. You can retry or add a new member directly.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _f = _svc.listUsers()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openCreateUserDialog,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Member'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
