import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:retail_verse_pos/features/super_admin/presentation/screens/sa_shell.dart';

class SaLogsScreen extends StatefulWidget {
  const SaLogsScreen({super.key});

  @override
  State<SaLogsScreen> createState() => _SaLogsScreenState();
}

class _SaLogsScreenState extends State<SaLogsScreen> with SingleTickerProviderStateMixin {
  final _svc = SuperAdminService();
  late Future<List<Map<String, dynamic>>> _f;
  late AnimationController _animC;
  String _activeFilter = 'All Events';

  @override
  void initState() {
    super.initState();
    _f = _svc.listAuditLogs(limit: 100);
    _animC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  }

  @override
  void dispose() {
    _animC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          _buildFilterTabs(),
          SliverFillRemaining(
            hasScrollBody: true,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                List<Map<String, dynamic>> items = snap.data ?? [];
                
                // Real filtering logic
                if (_activeFilter != 'All Events') {
                  items = items.where((l) {
                    final action = l['action']?.toString().toUpperCase() ?? '';
                    if (_activeFilter == 'Security') return action.contains('LOGIN') || action.contains('AUTH') || action.contains('DELETE');
                    if (_activeFilter == 'System') return action.contains('CONFIG') || action.contains('DOMAIN');
                    if (_activeFilter == 'Business') return action.contains('BIZ') || action.contains('BUSINESS');
                    return true;
                  }).toList();
                }

                if (items.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() { _f = _svc.listAuditLogs(limit: 100); });
                    await _f;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _buildTimelineLog(items[i], i == 0, i == items.length - 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (saScaffoldNavigationKey.currentState?.hasDrawer ?? false)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          onPressed: () => saScaffoldNavigationKey.currentState?.openDrawer(),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PLATFORM SECURITY', style: AppTypography.labelSmall.copyWith(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('Audit Logs', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                _Bounceable(
                  onTap: () => setState(() => _f = _svc.listAuditLogs(limit: 100)),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(top: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _buildFilterItem('All Events', Icons.all_inclusive_rounded),
            _buildFilterItem('Security', Icons.lock_outline_rounded),
            _buildFilterItem('System', Icons.settings_input_component_rounded),
            _buildFilterItem('Business', Icons.storefront_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterItem(String label, IconData icon) {
    final isActive = _activeFilter == label;
    return _Bounceable(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.cardBorder),
          boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.labelSmall.copyWith(color: isActive ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineLog(Map<String, dynamic> l, bool isFirst, bool isLast) {
    final action = l['action']?.toString().toUpperCase() ?? 'SYSTEM_EVENT';
    final actor = l['actorEmail']?.toString() ?? 'SYSTEM';
    final atStr = l['createdAt']?.toString() ?? '';
    final biz = l['businessId']?.toString() ?? '';
    
    DateTime at = DateTime.tryParse(atStr) ?? DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(at);
    final dateStr = DateFormat('MMM dd, yyyy').format(at);

    Color typeColor = Colors.blue;
    if (action.contains('DELETE') || action.contains('REMOVE')) typeColor = Colors.red;
    if (action.contains('CREATE') || action.contains('ADD')) typeColor = Colors.green;
    if (action.contains('UPDATE') || action.contains('EDIT')) typeColor = Colors.orange;

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(width: 2, height: 16, color: isFirst ? Colors.transparent : Colors.grey.withOpacity(0.2)),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: typeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: typeColor.withOpacity(0.2), width: 3),
                ),
              ),
              Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : Colors.grey.withOpacity(0.2))),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _Bounceable(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(action, style: AppTypography.labelSmall.copyWith(color: typeColor, fontWeight: FontWeight.w900, fontSize: 10)),
                          ),
                          Text(timeStr, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Performed by $actor', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      if (biz.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Target Business ID: $biz', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 10, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(dateStr, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, fontSize: 9)),
                          const Spacer(),
                          Text('LOG ID: ${l['_id']?.toString().substring(l['_id'].toString().length - 6).toUpperCase() ?? "N/A"}', style: TextStyle(color: AppColors.textTertiary, fontSize: 8, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security_update_warning_rounded, size: 80, color: AppColors.textTertiary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('All clear. No recent logs.', style: AppTypography.titleMedium.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
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
