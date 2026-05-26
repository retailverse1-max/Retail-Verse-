import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/remote/super_admin_service.dart';
import '../widgets/support_dialog.dart';

class SaStoresPerformanceScreen extends ConsumerStatefulWidget {
  const SaStoresPerformanceScreen({super.key});

  @override
  ConsumerState<SaStoresPerformanceScreen> createState() => _SaStoresPerformanceScreenState();
}

class _SaStoresPerformanceScreenState extends ConsumerState<SaStoresPerformanceScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _svc = SuperAdminService();
  
  late Future<List<Map<String, dynamic>>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _storesFuture = _svc.getTopPerformanceStores();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stores = snapshot.data ?? [];
          final filteredStores = stores.where((s) => (s['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return CustomScrollView(
            slivers: [
              // ── PREMIUM HEADER ─────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Text('Store Analytics', style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Top Performance', style: AppTypography.labelLarge.copyWith(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Text('Leaderboard', style: AppTypography.displaySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 32),
                        // Search Bar
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search stores...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.7)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── PERFORMANCE LIST ──────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final store = filteredStores[index];
                      return FadeTransition(
                        opacity: _fadeController,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: Interval((index / (filteredStores.isEmpty ? 1 : filteredStores.length)), 1.0, curve: Curves.easeOutCubic),
                            ),
                          ),
                          child: _StorePerformanceCard(store: store),
                        ),
                      );
                    },
                    childCount: filteredStores.length,
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _StorePerformanceCard extends StatelessWidget {
  final Map<String, dynamic> store;
  const _StorePerformanceCard({required this.store});

  @override
  Widget build(BuildContext context) {
    // Generate a consistent color based on name
    final List<Color> colors = [Colors.blue, Colors.purple, Colors.green, Colors.orange, Colors.pink, Colors.teal, Colors.indigo];
    final Color color = colors[store['name'].toString().length % colors.length];
    
    final String growth = store['growth']?.toString() ?? '+0.0%';
    final bool isPositive = growth.startsWith('+');
    final num revenue = store['revenue'] ?? 0;
    final num orders = store['orders'] ?? 0;
    final num customers = store['customers'] ?? 0;
    final num health = store['health'] ?? 0.95;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showStoreDetails(context, store, color);
          },
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.store_rounded, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store['name'] ?? 'Unknown Store', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900)),
                          Text('$customers Unique Customers', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isPositive ? AppColors.success : AppColors.error).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        growth,
                        style: TextStyle(
                          color: isPositive ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMetric('Revenue', '₹${revenue.toInt()}', Icons.account_balance_wallet_rounded),
                    _buildMiniMetric('Orders', orders.toString(), Icons.shopping_bag_rounded),
                    _buildMiniMetric('Health', '${(health * 100).toInt()}%', Icons.favorite_rounded),
                  ],
                ),
                const SizedBox(height: 20),
                // Performance Bar (Scaled based on a target of 1L for now)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (revenue / 100000.0).clamp(0.0, 1.0),
                    backgroundColor: color.withOpacity(0.1),
                    color: color,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }

  void _showStoreDetails(BuildContext context, Map<String, dynamic> store, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StoreDetailSheet(store: store, themeColor: color),
    );
  }
}

class _StoreDetailSheet extends StatelessWidget {
  final Map<String, dynamic> store;
  final Color themeColor;
  const _StoreDetailSheet({required this.store, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final num revenue = store['revenue'] ?? 0;
    final num customers = store['customers'] ?? 0;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store['name'] ?? 'Store Details', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900)),
                          Text('Store ID: ${store['_id']?.toString().substring(store['_id'].toString().length - 6).toUpperCase() ?? 'N/A'}', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.store_rounded, color: themeColor, size: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Month Performance'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _DetailStatCard(label: 'Total Revenue', value: '₹${revenue.toInt()}', color: themeColor)),
                    const SizedBox(width: 16),
                    Expanded(child: _DetailStatCard(label: 'Active Customers', value: customers.toString(), color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Module Status'),
                const SizedBox(height: 16),
                _buildModuleTile('Inventory Management', 'ACTIVE', Icons.inventory_2_rounded, Colors.green),
                _buildModuleTile('Staff Attendance', 'PENDING', Icons.badge_rounded, Colors.orange),
                _buildModuleTile('Financial Reports', 'ACTIVE', Icons.analytics_rounded, Colors.blue),
                _buildModuleTile('Custom Domain', 'DISABLED', Icons.language_rounded, Colors.grey),
                const SizedBox(height: 32),
                _buildSectionTitle('Quick Actions'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _ActionButton(label: 'View Logs', icon: Icons.history_rounded, onTap: () {})),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionButton(label: 'Edit Plan', icon: Icons.edit_calendar_rounded, onTap: () {})),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionButton(label: 'Suspend', icon: Icons.block_rounded, color: Colors.red, onTap: () {})),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900));
  }

  Widget _buildModuleTile(String name, String status, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, {Color? color, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (color ?? AppColors.primary).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color ?? AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: color ?? AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DetailStatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (color ?? AppColors.primary).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color ?? AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: color ?? AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
