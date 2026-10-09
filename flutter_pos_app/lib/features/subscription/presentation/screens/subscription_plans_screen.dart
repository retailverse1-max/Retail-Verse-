import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/repositories/subscription_repository.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/data/remote/payment_service.dart';
// Using native dialogs instead of Razorpay for compliance

class SubscriptionPlansScreen extends ConsumerStatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  ConsumerState<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends ConsumerState<SubscriptionPlansScreen> {
  SubscriptionPlan? _selectedPlan;
  bool _isProcessing = false;

  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showError(String message, {Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString().contains('SocketException') || err.toString().contains('Failed host lookup') ? 'You are offline. Please check your internet connection.' : 'Error: $err')),
        data: (plans) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Upgrade Your RetailVerse',
                      style: AppTypography.displaySmall.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a plan that scales with your business.',
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
            
                    // Plans Layout
                    Builder(
                      builder: (context) {
                        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                        if (isLandscape) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            child: IntrinsicHeight(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: plans.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  return Padding(
                                    padding: EdgeInsets.only(right: index == plans.length - 1 ? 0 : 24.0),
                                    child: _buildPlanCard(entry.value),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: plans.map((plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: _buildPlanCard(plan),
                          )).toList(),
                        );
                      },
                    ),
                    // Removed global button as per user request
                    SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    final isPro = plan.name.toLowerCase() == 'plus';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer( duration: const Duration(milliseconds: 300), 
        width: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.02) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: isPro,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ),
            Text(
              plan.name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            // Prices removed to comply with Google Play Payments policy (B2B exemption safe-guard)
            const SizedBox(height: 32),
            ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, size: 14, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(feature, style: AppTypography.bodyMedium),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  setState(() => _selectedPlan = plan);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Enterprise Upgrade'),
                      content: const Text('To upgrade or modify your subscription plan, please contact your account manager or our enterprise support team.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Understood'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context.push('/support');
                          },
                          child: const Text('Contact Support'),
                        ),
                      ],
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isSelected ? AppColors.primary : AppColors.cardBorder,
                  foregroundColor: isSelected ? Colors.white : AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isProcessing && isSelected
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'GO',
                        style: AppTypography.titleMedium.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
