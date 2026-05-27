import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';

enum _CardPaymentStep { swipe, pin, processing, success }

class CardPaymentSimulationDialog extends StatefulWidget {
  final double amount;
  const CardPaymentSimulationDialog({super.key, required this.amount});

  @override
  State<CardPaymentSimulationDialog> createState() => _CardPaymentSimulationDialogState();
}

class _CardPaymentSimulationDialogState extends State<CardPaymentSimulationDialog> {
  _CardPaymentStep _step = _CardPaymentStep.swipe;
  String _pin = '';
  
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
                  'Card Payment',
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
      case _CardPaymentStep.swipe:
        return Column(
          children: [
            const Icon(Icons.credit_card_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('Please swipe or insert card', style: AppTypography.titleMedium),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => setState(() => _step = _CardPaymentStep.pin),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Simulate Card Swiped'),
              ),
            ),
          ],
        );
      case _CardPaymentStep.pin:
        return Column(
          children: [
            Text('Enter PIN', style: AppTypography.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            _buildNumpad(),
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

  Widget _buildNumpad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        for (var i = 1; i <= 9; i++) _NumpadButton(label: '$i', onTap: () => _addPin('$i')),
        const SizedBox(),
        _NumpadButton(label: '0', onTap: () => _addPin('0')),
        _NumpadButton(
          label: '⌫',
          onTap: () {
            if (_pin.isNotEmpty) {
              setState(() => _pin = _pin.substring(0, _pin.length - 1));
            }
          },
        ),
      ],
    );
  }

  void _addPin(String digit) {
    if (_pin.length < 4) {
      setState(() => _pin += digit);
      if (_pin.length == 4) {
        _processPayment();
      }
    }
  }

  void _processPayment() async {
    setState(() => _step = _CardPaymentStep.processing);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _step = _CardPaymentStep.success);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context, true);
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumpadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
