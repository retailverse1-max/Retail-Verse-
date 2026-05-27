import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

class SaAnalyticsScreen extends StatefulWidget {
  const SaAnalyticsScreen({super.key});

  @override
  State<SaAnalyticsScreen> createState() => _SaAnalyticsScreenState();
}

class _SaAnalyticsScreenState extends State<SaAnalyticsScreen> with SingleTickerProviderStateMixin {
  final _svc = SuperAdminService();
  late Future<Map<String, dynamic>> _f;
  late AnimationController _animC;

  @override
  void initState() {
    super.initState();
    _f = _svc.getAnalyticsSummary();
    _animC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() {
    _animC.dispose();
    super.dispose();
  }

  static num _n(dynamic v) => (v is num) ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: AppTypography.titleMedium));
          }

          final data = snap.data?['data'] ?? {};
          final cards = data['cards'] ?? {};
          final trends = (data['trends'] as List?) ?? [];
          final distribution = (data['distribution'] as List?) ?? [];
          final perBiz = (data['perBusinessOrders'] as List?) ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _f = _svc.getAnalyticsSummary();
              });
              await _f;
            },
            child: CustomScrollView(
              slivers: [
                _buildHeader(),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeTransition(
                        opacity: _animC,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animC, curve: Curves.easeOutBack)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetricsGrid(cards),
                              const SizedBox(height: 32),
                              _buildSectionTitle('Platform Growth'),
                              const SizedBox(height: 16),
                              _buildOrderTrendChart(trends),
                              const SizedBox(height: 32),
                              _buildSectionTitle('Ecosystem Balance'),
                              const SizedBox(height: 16),
                              _buildDistributionPie(distribution),
                              const SizedBox(height: 32),
                              _buildSectionTitle('Top Performing Stores'),
                              const SizedBox(height: 16),
                              ...perBiz.map((b) => _buildBusinessCard(b)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: () => saScaffoldNavigationKey.currentState?.openDrawer(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PLATFORM INSIGHTS', style: AppTypography.labelSmall.copyWith(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('Analytics', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(), style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 0.5));
  }

  Widget _buildMetricsGrid(Map cards) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _MetricTile('Total Revenue', '₹${NumberFormat.compact().format(_n(cards['totalRevenue']))}', Icons.payments_rounded, Colors.blue, () {}),
        _MetricTile('Total Orders', '${_n(cards['totalOrders'])}', Icons.shopping_bag_rounded, Colors.orange, () {}),
        _MetricTile('Clients', '${_n(cards['totalBusinesses'])}', Icons.storefront_rounded, Colors.indigo, () {
          // Navigate to Businesses
        }),
        _MetricTile('Growth', '${cards['growthRate'] ?? '12.5%'}', Icons.trending_up_rounded, Colors.green, () {}),
      ],
    );
  }

  Widget _MetricTile(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return _AnimatedTapCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                _buildLivePulse(color),
              ],
            ),
            const Spacer(),
            Text(value, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
            Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePulse(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildOrderTrendChart(List trends) {
    if (trends.isEmpty) return _buildEmptyChart();
    
    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), _n(trends[i]['revenue']).toDouble()));
    }

    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 240,
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppColors.shadowSubtle,
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: AppColors.primary,
                getTooltipItems: (items) => items.map((it) => LineTooltipItem('₹${it.y.toInt()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList(),
              ),
            ),
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.4), AppColors.primary.withOpacity(0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.cardBorder)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph_rounded, color: AppColors.textTertiary.withOpacity(0.3), size: 40),
          const SizedBox(height: 12),
          Text('Waiting for more data...', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildDistributionPie(List dist) {
    if (dist.isEmpty) return const SizedBox.shrink();
    
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
    
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.shadowSubtle),
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: List.generate(dist.length, (i) {
                    final val = _n(dist[i]['count']).toDouble();
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: val,
                      title: '${val.toInt()}',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(dist.length, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(dist[i]['_id']?.toString().toUpperCase() ?? 'OTHER', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCard(Map b) {
    final name = b['businessId']?.toString() ?? 'Unknown';
    final rev = _n(b['revenue']);
    final orders = _n(b['orders']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AnimatedTapCard(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900)),
                    Text('$orders Orders', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Text('₹${NumberFormat.compact().format(rev)}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.success)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _AnimatedTapCard({required this.child, required this.onTap});

  @override
  State<_AnimatedTapCard> createState() => _AnimatedTapCardState();
}

class _AnimatedTapCardState extends State<_AnimatedTapCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
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

