import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';

class SaUsersScreen extends StatefulWidget {
  const SaUsersScreen({super.key});

  @override
  State<SaUsersScreen> createState() => _SaUsersScreenState();
}

class _SaUsersScreenState extends State<SaUsersScreen> {
  final _svc = SuperAdminService();
  late Future<List<Map<String, dynamic>>> _f;
  String _searchQ = '';
  final _searchC = TextEditingController();

  static const _assignableRoles = ['super_admin', 'admin', 'cashier', 'inventory', 'user'];

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User & Access', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                        Text('Manage platform staff & roles', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _openCreateUserDialog,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  return _buildErrorState(snap.error.toString());
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
                      style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : 'Unnamed Member', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      Text(email, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildRoleBadge(role),
                          const SizedBox(width: 8),
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

  Widget _buildRoleBadge(String role) {
    final displayRole = role.toLowerCase() == 'admin' ? 'client' : role;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        displayRole.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 10),
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
          child: Text('Assign ${r == 'admin' ? 'CLIENT' : r.toUpperCase()}'),
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
        await _svc.updateUserStatus(userId: id, isActive: !active);
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
            content: const Text('Team updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    var role = _assignableRoles.first;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Add Member', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernField(nameC, 'Full Name', Icons.person_rounded),
                  const SizedBox(height: 16),
                  _buildModernField(emailC, 'Work Email', Icons.email_rounded),
                  const SizedBox(height: 16),
                  _buildModernField(passC, 'Initial Password', Icons.lock_rounded, obscure: true),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: _assignableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'admin' ? 'CLIENT' : r.toUpperCase()))).toList(),
                    onChanged: (v) => setLocal(() => role = v!),
                    decoration: InputDecoration(
                      labelText: 'Assigned Role',
                      prefixIcon: const Icon(Icons.shield_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      try {
        await _svc.createUser(name: nameC.text, email: emailC.text, password: passC.text, role: role);
        if (mounted) setState(() { _f = _svc.listUsers(); });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildModernField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        filled: true,
        fillColor: AppColors.backgroundSecondary.withOpacity(0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.group_add_rounded, size: 80, color: AppColors.primary.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          Text('Your team is empty', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          Text('Add members to manage the platform.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Oops! Something went wrong', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => setState(() => _f = _svc.listUsers()), child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
