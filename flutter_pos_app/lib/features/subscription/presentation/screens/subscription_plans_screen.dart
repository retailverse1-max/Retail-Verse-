import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/repositories/subscription_repository.dart';
import 'package:retail_verse_pos/features/auth/providers/auth_provider.dart';
import 'package:retail_verse_pos/data/remote/payment_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class SubscriptionPlansScreen extends ConsumerStatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  ConsumerState<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends ConsumerState<SubscriptionPlansScreen> {
  SubscriptionPlan? _selectedPlan;
  bool _isProcessing = false;

  late Razorpay _razorpay;
  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startRazorpayPayment(SubscriptionPlan plan) async {
    setState(() => _isProcessing = true);
    try {
      // 1. Create razorpay order from our backend
      final orderRes = await _paymentService.createRazorpayOrder(
        amount: plan.price,
        currency: 'INR',
        receipt: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      );

      final razorpayOrderId = orderRes['razorpayOrderId'];
      final razorpayKeyId = orderRes['keyId'];

      if (razorpayOrderId == null || razorpayKeyId == null) {
        throw Exception('Invalid response from payment server');
      }

      // 2. Open razorpay SDK
      final auth = ref.read(authProvider);
      final user = auth.user ?? {};
      
      var options = {
        'key': razorpayKeyId,
        'amount': orderRes['amount'], // paise from backend
        'name': 'Retail Verse',
        'description': 'Upgrade to ${plan.name} Plan',
        'order_id': razorpayOrderId,
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
        'prefill': {
          'contact': user['phone'] ?? '',
          'email': user['email'] ?? '',
          'name': user['name'] ?? ''
        },
        'theme': {'color': '#163F6B'},
      };

      _razorpay.open(options);
    } catch (e) {
      _showError('Failed to start payment: $e');
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ Razorpay Success: ${response.paymentId}');
    try {
      // Step 3: Verify payment on backend
      final verifyRes = await _paymentService.verifyRazorpayPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
      );

      if (verifyRes['success'] == true) {
        // Now hit the subscription upgrade endpoint
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.upgradeSubscription(_selectedPlan!.id);
        
        await ref.read(authProvider.notifier).updateLocalUser({
          'subscriptionPlan': _selectedPlan!.name,
          'subscriptionStatus': 'active',
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully upgraded to ${_selectedPlan!.name}!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard'); 
        }
      } else {
        _showError('Payment verification failed. Please contact support.');
      }
    } catch (e) {
      _showError('Payment verification error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay Error: ${response.message}');
    _showError('Payment failed: ${response.message}');
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallets are not supported yet.');
    setState(() => _isProcessing = false);
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
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (plans) {
          return Center(
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
                    style: AppTypography.displaySmall.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a plan that scales with your business.',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Plans Row / Column
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: plans.map((plan) => _buildPlanCard(plan)).toList(),
                  ),
                  
                  const SizedBox(height: 48),
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: 300,
                      height: 56,
                      child: FilledButton(
                        onPressed: _selectedPlan == null ? null : () => _startRazorpayPayment(_selectedPlan!),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _selectedPlan == null ? 'Select a Plan' : 'Proceed to Payment',
                          style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    final isPro = plan.name.toLowerCase() == 'pro';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
            if (isPro)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₹${plan.price.toInt()}',
                  style: AppTypography.displayMedium.copyWith(fontWeight: FontWeight.w900, fontSize: 36),
                ),
                Text(
                  ' / mo',
                  style: AppTypography.titleMedium.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
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
          ],
        ),
      ),
    );
  }
}

