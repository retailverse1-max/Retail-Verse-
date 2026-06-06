import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';
import 'package:retail_verse_pos/features/dashboard/providers/dashboard_providers.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/routes/app_router.dart';
import 'package:retail_verse_pos/core/navigation/role_nav.dart';

// ── 1. PREMIUM HERO HEADER ─────────────────────
class PremiumHeroHeader extends StatefulWidget {
  final String userName;
  final double totalSales;
  final int totalOrders;
  final List<Widget>? actions;
  final String? subtitle;

  const PremiumHeroHeader({
    super.key,
    required this.userName,
    this.totalSales = 0,
    this.totalOrders = 0,
    this.actions,
    this.subtitle,
  });

  @override
  State<PremiumHeroHeader> createState() => _PremiumHeroHeaderState();
}

class _PremiumHeroHeaderState extends State<PremiumHeroHeader> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  void _handleSearch(BuildContext context, WidgetRef ref) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
      });
      ref.read(dashboardSearchQueryProvider.notifier).state = null;
      return;
    }

    // 1. Check Menu Routes
    final user = ref.read(authProvider).user;
    final role = user?['role'] ?? user?['userRole'] ?? 'unknown';
    final navItems = drawerNavItemsForRole(role);
    
    try {
      final screenMatch = navItems.firstWhere(
        (item) => item.label.toLowerCase().contains(query) || item.route.toLowerCase().contains(query),
      );
      
      // Found a matching screen!
      ref.read(dashboardSearchQueryProvider.notifier).state = null;
      setState(() {
        _isSearching = false;
        _searchController.clear();
      });
      context.push(screenMatch.route);
      return;
    } catch (_) {
      // Not a screen, continue to product search
    }

    // 2. Check Products
    final products = ref.read(dashboardProductsProvider).value ?? [];
    try {
      final match = products.firstWhere(
        (p) => p.name.toLowerCase().contains(query) || p.sku.toLowerCase() == query,
      );

      final isRealMatch = match.name.toLowerCase().contains(query) || match.sku.toLowerCase() == query;

      if (isRealMatch) {
        ref.read(dashboardSearchQueryProvider.notifier).state = null;
        context.push('/pos/product', extra: match);
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
        return;
      }
    } catch (_) {
      // Not a product either
    }

    // 3. Not found
    ref.read(dashboardSearchQueryProvider.notifier).state = query;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final isPhone = width < 600;

    return Consumer(
      builder: (context, ref, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.accent, // Dark Navy
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Left: Menu and Logo ──
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ResponsiveMenuButton(color: Colors.white),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.subtitle ?? 'Good morning,',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyLarge.copyWith(color: Colors.white70)),
                                  Text(widget.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Right: Search Bar and Notifications ──
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isSearching ? (isPhone ? width - 160 : 350) : 46,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isSearching ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: _isSearching
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                                    onChanged: (v) {
                                      if (v.isEmpty) {
                                        ref.read(dashboardSearchQueryProvider.notifier).state = null;
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: isPhone ? 'Search...' : 'Search product or SKU...',
                                      hintStyle: TextStyle(color: Colors.black.withOpacity(0.4)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      prefixIcon: IconButton(
                                        icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                                        onPressed: () => _handleSearch(context, ref),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                                        onPressed: () {
                                          _searchController.clear();
                                          ref.read(dashboardSearchQueryProvider.notifier).state = null;
                                          setState(() => _isSearching = false);
                                        },
                                      ),
                                    ),
                                    onSubmitted: (_) => _handleSearch(context, ref),
                                  )
                                : InkWell(
                                    onTap: () => setState(() => _isSearching = true),
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.actions != null) Row(children: widget.actions!) else 
                          InkWell(
                            onTap: () => context.push('/notifications'),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // GLASS SUMMARY CONTAINER
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        _buildSummaryItem('Revenue', AppFormatters.formatCurrency(widget.totalSales)),
                        _buildDivider(),
                        _buildSummaryItem('Orders', widget.totalOrders.toString()),
                        _buildDivider(),
                        _buildStatusItem(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTypography.labelMedium.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTypography.headlineMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8));
  }

  Widget _buildStatusItem() {
    return Expanded(
      child: Column(
        children: [
          Text('Status', style: AppTypography.labelMedium.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('LIVE', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 2. PREMIUM SEARCH HEADER ──────────────────
class PremiumSearchHeader extends StatelessWidget {
  final String title;
  final Widget searchBar;
  final Widget? bottom;
  final List<Widget>? actions;

  const PremiumSearchHeader({
    super.key,
    required this.title,
    required this.searchBar,
    this.bottom,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.accent, // Dark Navy
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const ResponsiveMenuButton(color: Colors.white),
                    const SizedBox(width: 16),
                    Text(title, style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
                if (actions != null) Row(children: actions!),
              ],
            ),
          const SizedBox(height: 20),
          searchBar,
          if (bottom != null) ...[
            const SizedBox(height: 20),
            bottom!,
          ],
        ],
      ),
    ),
  );
  }
}

// ── 3. SAAS KPI CARD ──────────────────────
class SaaSKPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const SaaSKPICard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
          ],
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = constraints.maxHeight;
            
            // If the card is too short (e.g. landscape phone or small layout),
            // use a horizontal layout to prevent vertical overflow!
            if (cardHeight < 150) {
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (subtitle != null && cardHeight > 95) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }

            // Standard beautiful vertical layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    if (subtitle != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 4. PREMIUM SECTION CARD ──────────────────
class PremiumSectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsets? padding;

  const PremiumSectionCard({super.key, required this.child, this.title, this.padding});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(title!, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
            ],
            border: Border.all(color: AppColors.cardBorder.withOpacity(0.6)),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ── 5. PREMIUM FLOATING NAV BAR ──────────────
class PremiumFloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<PremiumNavItem> items;
  final Function(int) onDestinationSelected;
  final String? role;

  const PremiumFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.role,
  });

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'More Operations',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a module to navigate',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: items.length - 4,
                itemBuilder: (context, index) {
                  final actualIndex = index + 4;
                  final item = items[actualIndex];
                  final isSelected = selectedIndex == actualIndex;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onDestinationSelected(actualIndex);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.cardBorder.withOpacity(0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shouldTruncate = items.length > 5;
    final displayItems = shouldTruncate ? items.sublist(0, 4) : items;
    final isMoreSelected = shouldTruncate && selectedIndex >= 4;

    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.accent, // Dark Blue
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          if (role != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  role!.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ...List.generate(displayItems.length, (index) {
                  final isSelected = !isMoreSelected && selectedIndex == index;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onDestinationSelected(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isSelected ? displayItems[index].selectedIcon : displayItems[index].icon,
                              color: isSelected ? AppColors.primary : Colors.white70,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayItems[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: isSelected ? AppColors.primary : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (shouldTruncate)
                  Expanded(
                    child: InkWell(
                      onTap: () => _showMoreSheet(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMoreSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isMoreSelected ? Icons.apps_rounded : Icons.more_horiz_rounded,
                              color: isMoreSelected ? AppColors.primary : Colors.white70,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'More',
                            style: AppTypography.labelSmall.copyWith(
                              color: isMoreSelected ? AppColors.primary : Colors.white70,
                              fontWeight: isMoreSelected ? FontWeight.w900 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const PremiumNavItem({required this.label, required this.icon, required this.selectedIcon});
}

// ── 6. SECTION HEADER ─────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onActionTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
          if (onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(actionLabel ?? 'View All',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── 7. MODERN LINE CHART ──────────────────
class ModernLineChart extends StatefulWidget {
  final String title;
  final String value;
  final String change;
  final List<double> data;
  final Color color;

  const ModernLineChart({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.data,
    this.color = AppColors.primary,
  });

  @override
  State<ModernLineChart> createState() => _ModernLineChartState();
}

class _ModernLineChartState extends State<ModernLineChart> with SingleTickerProviderStateMixin {
  late List<double> _currentData;
  late AnimationController _controller;
  bool _isLive = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentData = List.from(widget.data);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _toggleLive() {
    setState(() {
      _isLive = !_isLive;
    });

    if (_isLive) {
      _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (!mounted) return;
        setState(() {
          // Shift data left and add a new random point near the last one
          final last = _currentData.last;
          // Add a base fluctuation even if last is 0 to keep it "alive"
          final baseFluct = last == 0 ? 5.0 : (last * 0.1);
          final fluctuation = (math.Random().nextDouble() - 0.5) * baseFluct;
          _currentData.removeAt(0);
          _currentData.add((last + fluctuation).clamp(0.0, 1000000.0));
        });
      });
    } else {
      _timer?.cancel();
      setState(() {
        _currentData = List.from(widget.data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleLive,
      borderRadius: BorderRadius.circular(32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLive 
              ? [const Color(0xFF4F46E5), const Color(0xFF312E81)] 
              : [const Color(0xFF3730A3), const Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(_isLive ? 0.6 : 0.4), 
              blurRadius: _isLive ? 40 : 25, 
              spreadRadius: _isLive ? 5 : 0,
              offset: const Offset(0, 10)
            ),
          ],
          border: _isLive ? Border.all(color: Colors.white.withOpacity(0.3), width: 2) : null,
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
                    Row(
                      children: [
                        Text(widget.title, style: AppTypography.labelLarge.copyWith(color: Colors.white70)),
                        if (_isLive) ...[
                          const SizedBox(width: 8),
                          _LiveIndicator(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(widget.value, style: AppTypography.headlineMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.change, style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: TweenAnimationBuilder<List<double>>(
                tween: _DataListTween(begin: widget.data, end: _currentData),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return CustomPaint(
                    painter: _LineChartPainter(data: value, color: Colors.white),
                  );
                },
              ),
            ),
            if (_isLive) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'LIVE TRACKING ACTIVE',
                  style: AppTypography.labelSmall.copyWith(color: Colors.white54, letterSpacing: 1, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
      ),
    );
  }
}

class _DataListTween extends Tween<List<double>> {
  _DataListTween({super.begin, super.end});

  @override
  List<double> lerp(double t) {
    if (begin == null || end == null) return end ?? [];
    final List<double> result = [];
    final length = math.min(begin!.length, end!.length);
    for (int i = 0; i < length; i++) {
      result.add(begin![i] + (end![i] - begin![i]) * t);
    }
    return result;
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final xStep = size.width / (data.length - 1);
    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    double getY(double val) => size.height - ((val - minVal) / range * size.height);

    path.moveTo(0, getY(data[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final x = i * xStep;
      final y = getY(data[i]);
      
      final prevX = (i - 1) * xStep;
      final prevY = getY(data[i - 1]);
      path.cubicTo(
        prevX + xStep / 2, prevY,
        x - xStep / 2, y,
        x, y,
      );
      fillPath.cubicTo(
        prevX + xStep / 2, prevY,
        x - xStep / 2, y,
        x, y,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
// ── 8. PREMIUM ADMIN SIDEBAR ──────────────────
class PremiumAdminSidebar extends ConsumerWidget {
  final int selectedIndex;
  final List<PremiumNavItem> items;
  final Function(int) onDestinationSelected;
  final String? userName;
  final String? userEmail;
  final VoidCallback? onToggleCollapse;
  final bool isPinned;

  const PremiumAdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.userName,
    this.userEmail,
    this.onToggleCollapse,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.cardBorder.withOpacity(0.8), width: 1.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 30, offset: const Offset(5, 0)),
        ],
      ),
      child: Column(
        children: [
          // LOGO HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 16, 32),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Retail Verse',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: AppColors.accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onToggleCollapse != null)
                  IconButton(
                    icon: Icon(isPinned ? Icons.menu_open : Icons.menu),
                    color: AppColors.textSecondary,
                    onPressed: onToggleCollapse,
                    tooltip: isPinned ? 'Collapse Menu' : 'Pin Menu',
                  ),
              ],
            ),
          ),

          // NAV ITEMS
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                return _SidebarItem(
                  item: items[index],
                  isSelected: isSelected,
                  onTap: () => onDestinationSelected(index),
                );
              },
            ),
          ),

          // USER MINI CARD & PROFILE LINK
          if (userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: InkWell(
                onTap: () {
                  context.push('/account');
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Close drawer
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          userName![0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              userEmail ?? 'Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
                    ],
                  ),
                ),
              ),
            ),

          // LOGOUT BUTTON
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: InkWell(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final PremiumNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.2)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResponsiveMenuButton extends ConsumerWidget {
  final bool isSuperAdmin;
  final Color? color;
  
  const ResponsiveMenuButton({
    super.key, 
    this.isSuperAdmin = false,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isTabletWidth = width >= 600;

    final isPinned = isSuperAdmin 
        ? ref.watch(saSidebarPinnedProvider) 
        : ref.watch(sidebarPinnedProvider);
        
    final showPinnedSidebar = isTabletWidth && isLandscape && isPinned;

    if (showPinnedSidebar) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: () {
        if (isSuperAdmin) {
          saScaffoldNavigationKey.currentState?.openDrawer();
        } else {
          scaffoldNavigationKey.currentState?.openDrawer();
        }
      },
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.textPrimary).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSuperAdmin ? Icons.more_vert_rounded : Icons.menu_rounded, 
          color: color ?? AppColors.textPrimary, 
          size: 20
        ),
      ),
    );
  }
}
