import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/session_service.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../providers/auth_provider.dart';

/// Splash screen with logo and animation + session check
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Icon cycling animation state
  bool _showMainLogo = true;
  int _currentIconIndex = 0;
  final List<IconData> _cyclingIcons = [
    Icons.shopping_basket_rounded, // Grocery
    Icons.sports_soccer_rounded,   // Sports
    Icons.fastfood_rounded,        // Food
    Icons.checkroom_rounded,       // Fashion
    Icons.devices_other_rounded,   // Electronics
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
    _startSplashSequence();
    _checkSessionAndNavigate();
  }

  void _startSplashSequence() async {
    // Show main POS logo for 1.5 seconds first
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _showMainLogo = false;
      });
      _startIconCycling();
    }
  }

  void _startIconCycling() async {
    while (mounted && !_showMainLogo) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _currentIconIndex = (_currentIconIndex + 1) % _cyclingIcons.length;
        });
      }
    }
  }

  Future<void> _checkSessionAndNavigate() async {
    try {
      // Total splash duration: 1.5s (logo) + 3s (cycling) = 4.5s
      await Future.delayed(const Duration(milliseconds: 4500));

      final hasSession = await SessionService.hasSession();

      if (!mounted) return;

      if (hasSession) {
        await ref.read(authProvider.notifier).restoreFromStorage();
        if (!mounted) return;
        
        final home = initialHomeRouteForUser(ref.read(authProvider).user);
        context.go(home);
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Icon Ring / Circle
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 2),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: animation, 
                        child: FadeTransition(opacity: animation, child: child)
                      );
                    },
                    child: Icon(
                      _showMainLogo ? Icons.point_of_sale_rounded : _cyclingIcons[_currentIconIndex],
                      key: ValueKey<String>(_showMainLogo ? 'logo' : 'icon_$_currentIconIndex'),
                      color: AppColors.primary,
                      size: 70,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                AppConstants.appName.toUpperCase(),
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "MODERN RETAIL ECOSYSTEM",
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}