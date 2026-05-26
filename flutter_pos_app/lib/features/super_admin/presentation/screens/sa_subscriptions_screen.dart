import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:intl/intl.dart';

class SaSubscriptionsScreen extends StatefulWidget {
  const SaSubscriptionsScreen({super.key});

  @override
  State<SaSubscriptionsScreen> createState() => _SaSubscriptionsScreenState();
}

class _SaSubscriptionsScreenState extends State<SaSubscriptionsScreen> with SingleTickerProviderStateMixin {
  final _svc = SuperAdminService();
  late Future<List<Map<String, dynamic>>> _plansF;
  late Future<List<Map<String, dynamic>>> _bizF;
  late TabController _tabC;
  String _q = '';
  final _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _plansF = _svc.listSubscriptionPlans();
      _bizF = _svc.listBusinesses();
    });
  }

  @override
  void dispose() {
    _searchC.dispose();
    _tabC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildPremiumHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabC,
              children: [
                _buildClientsTab(),
                _buildPlansTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
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
                  Text('Subscriptions', style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w900)),
                  Text('Manage revenue and client access', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                onPressed: () {}, // Future: Open detailed analytics
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_graph_rounded, color: AppColors.primary, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSearchAndFilter(),
          const SizedBox(height: 24),
          _buildTabBar(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: TextField(
        controller: _searchC,
        onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by client or plan...',
          hintStyle: TextStyle(color: AppColors.textTertiary.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabC,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        tabs: const [
          Tab(text: 'CLIENTS'),
          Tab(text: 'CATALOG'),
        ],
      ),
    );
  }

  Widget _buildClientsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bizF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final rawItems = snap.data ?? [];
        
        // Calculate Metrics
        double totalRev = 0;
        int activeCount = 0;
        int expiringCount = 0;
        final now = DateTime.now();

        for (var b in rawItems) {
          if (b['subscriptionStatus'] == 'active') activeCount++;
          // Simulated revenue logic
          totalRev += (b['subscriptionPlan'] == 'enterprise' ? 4999 : 999);
          
          final expiryStr = b['subscriptionExpiry']?.toString();
          if (expiryStr != null) {
            final expiry = DateTime.tryParse(expiryStr);
            if (expiry != null && expiry.difference(now).inDays <= 7 && expiry.isAfter(now)) {
              expiringCount++;
            }
          }
        }

        final items = rawItems.where((b) {
          final name = (b['businessName'] ?? '').toString().toLowerCase();
          return name.contains(_q);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            children: [
              _buildMetricsGrid(totalRev, activeCount, expiringCount),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CLIENT ECOSYSTEM', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  Text('${items.length} TOTAL', style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ...items.map((b) => _buildModernClientCard(b)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(double revenue, int active, int expiring) {
    return Row(
      children: [
        _buildMetricCard('MRR', '₹${NumberFormat.compact().format(revenue)}', Icons.payments_rounded, Colors.blue),
        const SizedBox(width: 12),
        _buildMetricCard('ACTIVE', '$active', Icons.bolt_rounded, Colors.green),
        const SizedBox(width: 12),
        _buildMetricCard('EXPIRING', '$expiring', Icons.running_with_errors_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {}, // Future: Filter by status or show revenue details
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 12),
                Text(value, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 18), overflow: TextOverflow.ellipsis),
                Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernClientCard(Map<String, dynamic> b) {
    final name = b['businessName']?.toString() ?? 'Unnamed Ecosystem';
    final plan = b['subscriptionPlan']?.toString() ?? 'free';
    final status = b['subscriptionStatus']?.toString() ?? 'active';
    final expiryStr = b['subscriptionExpiry']?.toString();
    final bId = b['id']?.toString() ?? b['_id']?.toString() ?? '';
    
    DateTime? expiryDate;
    if (expiryStr != null) expiryDate = DateTime.tryParse(expiryStr);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => context.push('/super-admin/businesses/$bId'),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        _buildPlanBadge(plan),
                      ],
                    ),
                  ),
                  _buildStatusTag(status),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, thickness: 0.5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXPIRY DATE', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        expiryDate != null ? DateFormat('MMM dd, yyyy').format(expiryDate) : 'Not Set',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('DETAILS', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
      child: Text(plan.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 9)),
    );
  }

  Widget _buildStatusTag(String status) {
    final active = status.toLowerCase() == 'active';
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildPlansTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _plansF,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        final items = snap.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          itemCount: items.length,
          itemBuilder: (context, i) => _buildPremiumPlanCard(items[i]),
        );
      },
    );
  }

  Widget _buildPremiumPlanCard(Map<String, dynamic> p) {
    final code = p['code']?.toString() ?? 'PLAN';
    final price = p['price']?.toString() ?? '0';
    final period = p['billingPeriod']?.toString() ?? 'month';
    final isEnterprise = code.toLowerCase().contains('enterprise');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: isEnterprise ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder, width: isEnterprise ? 2 : 1),
      ),
      child: InkWell(
        onTap: () {}, // Action for editing/viewing plan
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          children: [
            if (isEnterprise)
              Positioned(
                right: 24,
                top: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Icon(isEnterprise ? Icons.auto_awesome_rounded : Icons.star_outline_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(code.toUpperCase(), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₹$price', style: AppTypography.displaySmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      Text('/ $period', style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  _buildFeatureRow('Advanced Inventory Control'),
                  _buildFeatureRow('Multi-Store Integration'),
                  _buildFeatureRow('Enterprise Audit Logs'),
                  _buildFeatureRow('Priority Support Access'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: isEnterprise ? AppColors.primary : const Color(0xFFF1F5F9),
                        foregroundColor: isEnterprise ? Colors.white : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('Update Plan Catalog', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
