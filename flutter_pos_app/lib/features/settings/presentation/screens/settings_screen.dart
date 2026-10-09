import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/settings/presentation/widgets/settings_page_content.dart';
import 'package:retail_verse_pos/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:retail_verse_pos/core/widgets/common/modern_search_bar.dart';
import 'package:retail_verse_pos/routes/app_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?['name'] ?? 'Admin';
    final userEmail = user?['email'] ?? 'No email linked';
    final userRole = user?['role']?.toString() ?? 'user';
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ... (Integrated Header)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (context.canPop())
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                            onPressed: () => context.pop(),
                          )
                        else
                          const ResponsiveMenuButton(),
                        const SizedBox(width: 12),
                        Text('Settings', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder.withOpacity(0.8)),
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search preferences...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      suffixIcon: _query.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _search.clear(); setState(() => _query = ''); }) 
                        : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.paddingOf(context).bottom + 120),
              children: [
                _buildPremiumUserCard(userName, userEmail, userRole),
                const SizedBox(height: 24),
                if (userRole == 'super_admin') ...[
                  _buildSuperAdminQuickAction(context),
                  const SizedBox(height: 32),
                ],
                SettingsPageContent(searchQuery: _query),
                const SizedBox(height: 40),
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminQuickAction(BuildContext context) {
    return _Bounceable(
      onTap: () => context.push('/super-admin/dashboard'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF1E1B4B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Super Admin Panel', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Control entire platform & businesses', style: AppTypography.labelSmall.copyWith(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumUserCard(String name, String email, String role) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(email, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: role == 'super_admin' ? AppColors.primary.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)
            ),
            child: Text(
              role == 'super_admin' ? 'SUPER ADMIN' : 'ACTIVE',
              style: TextStyle(
                color: role == 'super_admin' ? AppColors.primary : AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return _Bounceable(
      onTap: () => _showLogoutConfirmation(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 12),
            const Text('Sign Out From Device', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out? You will need to login again to access your store.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }
}

class _Bounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Bounceable({required this.child, required this.onTap});

  @override
  State<_Bounceable> createState() => _BounceableState();
}

class _BounceableState extends State<_Bounceable> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
