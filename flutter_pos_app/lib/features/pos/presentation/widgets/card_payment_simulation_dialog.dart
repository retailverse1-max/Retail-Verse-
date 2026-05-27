import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';

enum _CardPaymentStep { connecting, waiting, processing, success }

class CardPaymentSimulationDialog extends StatefulWidget {
  final double amount;
  const CardPaymentSimulationDialog({super.key, required this.amount});

  @override
  State<CardPaymentSimulationDialog> createState() => _CardPaymentSimulationDialogState();
}

class _CardPaymentSimulationDialogState extends State<CardPaymentSimulationDialog> {
  _CardPaymentStep _step = _CardPaymentStep.connecting;
  
  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() async {
    // 1. Connecting to terminal
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _step = _CardPaymentStep.waiting);

    // 2. Waiting for customer to swipe & enter PIN on terminal
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _step = _CardPaymentStep.processing);

    // 3. Processing payment
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _step = _CardPaymentStep.success);

    // 4. Success -> Close
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context, true);
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.background,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'External Card Terminal',
                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppFormatters.formatCurrency(widget.amount),
              style: AppTypography.headlineMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 32),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _CardPaymentStep.connecting:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Connecting to Terminal...', style: AppTypography.titleMedium),
            const SizedBox(height: 24),
          ],
        );
      case _CardPaymentStep.waiting:
        return Column(
          children: [
            const Icon(Icons.credit_card_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('Waiting for customer to swipe & enter PIN on the terminal...', 
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium),
            const SizedBox(height: 24),
          ],
        );
      case _CardPaymentStep.processing:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Processing Payment...', style: AppTypography.titleMedium),
            const SizedBox(height: 24),
          ],
        );
      case _CardPaymentStep.success:
        return Column(
          children: [
            const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.success),
            const SizedBox(height: 24),
            Text('Payment Successful', style: AppTypography.titleMedium.copyWith(color: AppColors.success)),
            const SizedBox(height: 24),
          ],
        );
    }
  }
}
