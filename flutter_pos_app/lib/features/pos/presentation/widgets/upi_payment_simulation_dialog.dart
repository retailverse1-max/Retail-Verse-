import 'dart:async';
import 'package:flutter/material.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';

enum _UpiPaymentStep { connecting, waiting, success }

class UpiPaymentSimulationDialog extends StatefulWidget {
  final double amount;
  const UpiPaymentSimulationDialog({super.key, required this.amount});

  @override
  State<UpiPaymentSimulationDialog> createState() => _UpiPaymentSimulationDialogState();
}

class _UpiPaymentSimulationDialogState extends State<UpiPaymentSimulationDialog> {
  _UpiPaymentStep _step = _UpiPaymentStep.connecting;
  Timer? _timer;
  int _secondsRemaining = 120;
  
  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSimulation() async {
    // 1. Connecting to Paytm terminal
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _step = _UpiPaymentStep.waiting);
    
    // Start 2 minute timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(duration: const Duration(seconds: 2),content: Text('UPI Payment QR Code Expired (2 mins).')),
          );
        }
      }
    });
  }

  void _simulateCustomerPaid() async {
    _timer?.cancel();
    setState(() => _step = _UpiPaymentStep.success);
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
                  'UPI (Paytm Terminal)',
                  style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w600),
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
              style: AppTypography.headlineMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
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
      case _UpiPaymentStep.connecting:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Connecting to Paytm Machine...', style: AppTypography.titleMedium),
            const SizedBox(height: 24),
          ],
        );
      case _UpiPaymentStep.waiting:
        final minutes = (_secondsRemaining / 60).floor();
        final seconds = _secondsRemaining % 60;
        final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        
        return Column(
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              timeString,
              style: AppTypography.headlineMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('QR Code generated on the Paytm machine.\nWaiting for customer to scan and pay...', 
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _simulateCustomerPaid,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.secondary,
                ),
                child: const Text('Simulate Payment Received'),
              ),
            ),
          ],
        );
      case _UpiPaymentStep.success:
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
