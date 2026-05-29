import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/widgets/support_dialog.dart';
import 'package:retail_verse_pos/features/support/presentation/widgets/support_fab.dart';
import 'package:retail_verse_pos/core/services/session_service.dart';
import 'package:retail_verse_pos/features/dashboard/providers/dashboard_providers.dart';

const _kPrimaryShellRoutes = <_SaRoute>[
  _SaRoute(label: 'Home', path: '/super-admin/dashboard', icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded),
  _SaRoute(label: 'Clients', path: '/super-admin/businesses', icon: Icons.apartment_outlined, selectedIcon: Icons.apartment_rounded),
  _SaRoute(label: 'User & Role', path: '/super-admin/users', icon: Icons.groups_outlined, selectedIcon: Icons.groups_rounded),
  _SaRoute(label: 'Customers', path: '/super-admin/customers', icon: Icons.people_outline, selectedIcon: Icons.people_rounded),
  _SaRoute(label: 'Contact Form', path: '/super-admin/contacts', icon: Icons.contact_mail_outlined, selectedIcon: Icons.contact_mail_rounded),
  _SaRoute(label: 'Invoice & Quotes', path: '/super-admin/orders', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded),
];

const _kSecondaryShellRoutes = <_SaRoute>[
  _SaRoute(label: 'Subscriptions', path: '/super-admin/subscriptions', icon: Icons.workspace_premium_outlined, selectedIcon: Icons.workspace_premium_rounded),
  _SaRoute(label: 'Analytics', path: '/super-admin/analytics', icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded),
  _SaRoute(label: 'Settings', path: '/super-admin/settings', icon: Icons.tune_outlined, selectedIcon: Icons.tune_rounded),
  _SaRoute(label: 'Custom Domain', path: '/super-admin/custom-domains', icon: Icons.language_outlined, selectedIcon: Icons.language_rounded),
  _SaRoute(label: 'Audit logs', path: '/super-admin/logs', icon: Icons.history_rounded, selectedIcon: Icons.history_rounded),
  _SaRoute(label: 'Support', path: '/super-admin/support', icon: Icons.support_agent_rounded, selectedIcon: Icons.support_agent_rounded),
];

final saSidebarPinnedProvider = StateProvider<bool>((ref) => false);
final saScaffoldNavigationKey = GlobalKey<ScaffoldState>();

class SuperAdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const SuperAdminShell({super.key, required this.child});

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
  final _svc = SuperAdminService();

  Future<void> _openClientStorePicker(BuildContext context) async {
    final items = await _svc.listBusinesses();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.paddingOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Store Control', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Switch control to a specific client store', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final b = items[i];
                  final name = b['businessName']?.toString() ?? b['businessId']?.toString() ?? 'Unknown';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(24), 
                      border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                      boxShadow: AppColors.shadowSubtle,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900)),
                      subtitle: const Text('Tap to switch context', style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                      onTap: () async {
                        final storeId = b['_id']?.toString() ?? b['businessId']?.toString();
                        if (storeId != null) {
                          await ref.read(authProvider.notifier).updateLocalUser({'storeId': storeId});
                          SessionService.currentStoreId = storeId;
                          invalidateAllDashboardProviders(ref);
                        }
                        Navigator.pop(ctx);
                        context.go('/dashboard');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final user = ref.watch(authProvider).user ?? {};
    final email = user['email']?.toString() ?? 'Super Admin';
    final width = MediaQuery.of(context).size.width;
    final isTabletWidth = width >= 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final canPinSidebar = isTabletWidth && isLandscape;
    final isPinned = ref.watch(saSidebarPinnedProvider);
    final showPinnedSidebar = canPinSidebar && isPinned;

    return Scaffold(
      key: saScaffoldNavigationKey,
      backgroundColor: AppColors.background,
      drawer: showPinnedSidebar ? null : _SuperAdminDrawer(
        email: email, 
        onStore: () => _openClientStorePicker(context), 
        onPick: (p) => context.push(p),
        canPin: canPinSidebar,
        isPinned: isPinned,
        onTogglePin: () {
          if (!showPinnedSidebar) {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            }
          }
          ref.read(saSidebarPinnedProvider.notifier).state = !isPinned;
        },
      ),
      // Screens provide their own headers
      floatingActionButton: const BlinkingSupportFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Row(
        children: [
          if (showPinnedSidebar)
            _SuperAdminDrawer(
              email: email,
              onStore: () => _openClientStorePicker(context),
              onPick: (p) => context.push(p),
              isDrawer: false,
              canPin: canPinSidebar,
              isPinned: isPinned,
              onTogglePin: () {
                ref.read(saSidebarPinnedProvider.notifier).state = !isPinned;
              },
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    final canPop = context.canPop();
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            canPop ? Icons.arrow_back_ios_new_rounded : Icons.more_vert_rounded, 
            color: AppColors.primary, 
            size: 18
          ),
        ), 
        onPressed: () {
          if (canPop) {
            context.pop();
          } else {
            saScaffoldNavigationKey.currentState?.openDrawer();
          }
        }
      ),
      title: Text('Retail Verse', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      actions: [
        IconButton(
          onPressed: () => _openClientStorePicker(context), 
          icon: const Icon(Icons.swap_horizontal_circle_outlined, color: AppColors.primary)
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _MoreToolIcon extends StatelessWidget {
  final _SaRoute route;
  final VoidCallback onTap;
  const _MoreToolIcon({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Icon(route.icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            route.label, 
            textAlign: TextAlign.center, 
            style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)
          ),
        ],
      ),
    );
  }
}

class _SuperAdminDrawer extends ConsumerWidget {
  final String email;
  final VoidCallback onStore;
  final void Function(String path) onPick;
  final bool isDrawer;
  final bool canPin;
  final bool isPinned;
  final VoidCallback? onTogglePin;

  const _SuperAdminDrawer({
    required this.email,
    required this.onStore,
    required this.onPick,
    this.isDrawer = true,
    this.canPin = false,
    this.isPinned = false,
    this.onTogglePin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24, 24, 24, 
              MediaQuery.paddingOf(context).bottom + 24
            ),
            children: [
              _buildDrawerSection(context, 'CORE MODULES', _kPrimaryShellRoutes),
              const SizedBox(height: 32),
              _buildDrawerSection(context, 'MORE TOOLS', _kSecondaryShellRoutes),
              const SizedBox(height: 32),
              _buildFooter(context, ref),
            ],
          ),
        ),
      ],
    );

    if (isDrawer) {
      return Drawer(
        backgroundColor: Colors.white,
        width: MediaQuery.of(context).size.width * 0.85,
        child: content,
      );
    } else {
      return Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.cardBorder.withOpacity(0.8), width: 1.5)),
        ),
        child: content,
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        top: isDrawer, // only top padding if inside drawer, otherwise custom padding works
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                ),
                if (canPin)
                  IconButton(
                    onPressed: onTogglePin,
                    icon: Icon(
                      isPinned ? Icons.code_rounded : Icons.code_off_rounded,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Retail Verse',
              style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            Text(
              email,
              style: AppTypography.bodySmall.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Text(
                'SUPER ADMIN',
                style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSection(BuildContext context, String title, List<_SaRoute> routes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 16), 
          child: Text(
            title, 
            style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w900, letterSpacing: 1.5)
          )
        ),
        ...routes.map((r) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(r.icon, size: 22, color: AppColors.textSecondary),
            title: Text(r.label, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () { 
              if (isDrawer && Navigator.of(context).canPop()) {
                Navigator.pop(context); 
              }
              onPick(r.path); 
            },
            hoverColor: AppColors.primary.withOpacity(0.05),
          ),
        )),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              if (isDrawer && Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
              onStore();
            },
            icon: const Icon(Icons.launch_rounded, size: 18),
            label: const Text('Launch Client POS'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            label: Text('Logout Retail Verse', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaRoute {
  final String label, path;
  final IconData icon, selectedIcon;
  const _SaRoute({required this.label, required this.path, required this.icon, required this.selectedIcon});
}

