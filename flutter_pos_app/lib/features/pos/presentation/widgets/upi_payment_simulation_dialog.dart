import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:retail_verse_pos/core/utils/formatters.dart';

enum _UpiState { waiting, expired, success }

class UpiPaymentSimulationDialog extends StatefulWidget {
  final double amount;
  final String storeName;
  final String upiVpa;

  const UpiPaymentSimulationDialog({
    super.key,
    required this.amount,
    this.storeName = 'RetailVerse POS',
    this.upiVpa = 'wehexerve@icici',
  });

  @override
  State<UpiPaymentSimulationDialog> createState() => _UpiPaymentSimulationDialogState();
}

class _UpiPaymentSimulationDialogState extends State<UpiPaymentSimulationDialog>
    with SingleTickerProviderStateMixin {
  _UpiState _state = _UpiState.waiting;
  Timer? _countdownTimer;
  int _secondsRemaining = 60; // 1-minute timer as requested
  late String _txId;
  late String _upiQrData;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _generateFreshQr();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _generateFreshQr() {
    _countdownTimer?.cancel();
    _txId = 'TXN${DateTime.now().millisecondsSinceEpoch.remainder(1000000)}';
    final amt = widget.amount.toStringAsFixed(2);
    // Real UPI deep link format readable by PhonePe, GPay, Paytm, BHIM
    _upiQrData = 'upi://pay?pa=${widget.upiVpa}&pn=${Uri.encodeComponent(widget.storeName)}&am=$amt&cu=INR&tn=$_txId';

    setState(() {
      _state = _UpiState.waiting;
      _secondsRemaining = 60; // 1 minute
    });

    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _state = _UpiState.expired;
        });
      }
    });
  }

  void _confirmPayment() async {
    _countdownTimer?.cancel();
    setState(() => _state = _UpiState.success);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UPI Terminal & Soundbox',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          'Paytm • GPay • PhonePe • BHIM',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // Amount banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payable Amount:',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      AppFormatters.formatCurrency(widget.amount),
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildBodyContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_state) {
      case _UpiState.waiting:
        final secondsStr = _secondsRemaining.toString().padLeft(2, '0');
        final isUrgent = _secondsRemaining <= 15;

        return Column(
          children: [
            // Dynamic QR Code Display with border
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                  width: isUrgent ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUrgent ? Colors.red : Colors.blue).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _upiQrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 1-minute countdown timer badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'QR Valid for 00:$secondsStr',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Show this QR to customer or on Paytm/GPay terminal display.\nWaiting for UPI soundbox / bank confirmation...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 18),

            // Actions row: Reset QR and Confirm Payment
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _generateFreshQr,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _confirmPayment,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Payment Received', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case _UpiState.expired:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_off_rounded, size: 54, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 14),
            const Text(
              'QR Code Expired (1 Min Limit)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Payment was not detected within 1 minute or customer cancelled. You can reset and regenerate a fresh QR code below:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel Payment', style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _generateFreshQr,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset & New QR', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case _UpiState.success:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Confirmed! 🎉',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF065F46)),
            ),
            const SizedBox(height: 6),
            Text(
              '₹${widget.amount.toStringAsFixed(2)} successfully received via UPI.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF047857), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text('Opening order confirmation & bill printing...', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
          ],
        );
    }
  }
}
