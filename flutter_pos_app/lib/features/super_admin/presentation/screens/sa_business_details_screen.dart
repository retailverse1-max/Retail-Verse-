import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/data/remote/super_admin_service.dart';
import 'package:intl/intl.dart';

class SaBusinessDetailsScreen extends StatefulWidget {
  final String businessId;
  const SaBusinessDetailsScreen({super.key, required this.businessId});

  @override
  State<SaBusinessDetailsScreen> createState() => _SaBusinessDetailsScreenState();
}

class _SaBusinessDetailsScreenState extends State<SaBusinessDetailsScreen> {
  final _svc = SuperAdminService();
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    return await _svc.getBusinessDetails(widget.businessId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Client Insight', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final stats = data['stats'] ?? {};
          final expiry = data['subscriptionExpiry'] != null 
              ? DateTime.parse(data['subscriptionExpiry']) 
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(data),
                const SizedBox(height: 32),
                _buildStatsGrid(stats),
                const SizedBox(height: 32),
                _buildSubscriptionCard(data, expiry),
                const SizedBox(height: 32),
                _buildContactInfo(data),
                const SizedBox(height: 48),
                _buildActionButtons(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? 'active';
    final isActive = status == 'active';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 40),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['businessName'] ?? 'Unknown Store', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ID: ${data['businessId'] ?? 'N/A'}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    return Row(
      children: [
        _buildStatCard('Inventory', stats['productCount']?.toString() ?? '0', Icons.inventory_2_rounded, Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard('Status', 'Active', Icons.bolt_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.shadowSubtle,
          border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 16),
            Text(value, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> data, DateTime? expiry) {
    final plan = data['subscriptionPlan']?.toString().toUpperCase() ?? 'FREE';
    final status = data['subscriptionStatus']?.toString().toUpperCase() ?? 'ACTIVE';
    final isPro = plan == 'PRO';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] : [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.shadowSubtle,
        border: Border.all(color: isPro ? Colors.transparent : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subscription Plan', style: AppTypography.bodySmall.copyWith(color: isPro ? Colors.white70 : AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPro ? Colors.amber : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  plan,
                  style: TextStyle(color: isPro ? Colors.black : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            status == 'ACTIVE' ? 'Status: Active' : 'Status: Expired',
            style: AppTypography.headlineSmall.copyWith(color: isPro ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            expiry != null 
              ? 'Ends on: ${DateFormat('dd MMM yyyy').format(expiry)}' 
              : 'Ends on: No Expiry Set',
            style: AppTypography.bodyMedium.copyWith(color: isPro ? Colors.white70 : AppColors.textSecondary),
          ),
          if (isPro) ...[
            const SizedBox(height: 20),
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.65, // Simulated
                child: Container(decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTACT INFORMATION', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        _buildInfoTile(Icons.person_outline_rounded, 'Owner', data['ownerName'] ?? 'N/A'),
        _buildInfoTile(Icons.email_outlined, 'Email', data['ownerEmail'] ?? 'N/A'),
        _buildInfoTile(Icons.phone_outlined, 'Phone', data['phone'] ?? 'N/A'),
        _buildInfoTile(Icons.location_on_outlined, 'Address', data['address'] ?? 'N/A'),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
              Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Manage Billing'),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
