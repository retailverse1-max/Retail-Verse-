import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../super_admin/presentation/widgets/support_dialog.dart';

class BlinkingSupportFAB extends StatefulWidget {
  const BlinkingSupportFAB({super.key});

  @override
  State<BlinkingSupportFAB> createState() => _BlinkingSupportFABState();
}

class _BlinkingSupportFABState extends State<BlinkingSupportFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80), // Offset to not overlap with nav bar
      child: FadeTransition(
        opacity: _controller,
        child: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const SupportDialog(),
            );
          },
          backgroundColor: AppColors.accent,
          shape: const CircleBorder(),
          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
