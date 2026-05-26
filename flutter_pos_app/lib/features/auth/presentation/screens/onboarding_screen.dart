import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '127152555107-mo61lp114l0e25128696iud0e0ul2q65.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCred.user != null) {
        if (!mounted) return;
        
        // Update AuthProvider state to sync with session
        await ref.read(authProvider.notifier).signInWithGoogle(userCred.user!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In successful'), backgroundColor: Colors.green),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.shortestSide >= 600;
    final double horizontalPadding = isTablet ? 40.0 : 24.0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── DYNAMIC BACKGROUND BLOBS ──────────────────
          Positioned(
            top: -50,
            left: -50,
            child: _buildBlob(isTablet ? 600 : 400, const Color(0xFF1E1B4B).withOpacity(0.08)),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: _buildBlob(isTablet ? 500 : 350, AppColors.primary.withOpacity(0.05)),
          ),
          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            
                            // ── CREATIVE HEADER ──────────────────────────
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(seconds: 1),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        height: isTablet ? 180 : 140,
                                        width: isTablet ? 180 : 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(0.2),
                                              AppColors.primary.withOpacity(0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: isTablet ? 110 : 90,
                                        width: isTablet ? 110 : 90,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(isTablet ? 36 : 28),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1E1B4B).withOpacity(0.3),
                                              blurRadius: 30,
                                              offset: const Offset(0, 15),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.point_of_sale_rounded,
                                          color: Colors.white,
                                          size: isTablet ? 55 : 45,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    AppConstants.appName,
                                    textAlign: TextAlign.center,
                                    style: (isTablet ? AppTypography.displayLarge : AppTypography.displayMedium).copyWith(
                                      color: const Color(0xFF1E1B4B),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 48 : 24),
                                    child: Text(
                                      "One Platform. Infinite Growth.\nExperience the future of Retail.",
                                      textAlign: TextAlign.center,
                                      style: (isTablet ? AppTypography.headlineSmall : AppTypography.bodyLarge).copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 60),
                            
                            // ── ACTION OPTIONS ──────────────────────────
                            Container(
                              constraints: const BoxConstraints(maxWidth: 450),
                              padding: const EdgeInsets.only(bottom: 60),
                              child: Column(
                                children: [
                                  // 1. Get Started (Primary Action)
                                  _buildPrimaryButton(
                                    context,
                                    title: 'Get Started',
                                    onPressed: () => context.go('/login'),
                                    isTablet: isTablet,
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // 2. Sign In with Google
                                  _buildCreativeButton(
                                    context,
                                    title: 'Sign in with Google',
                                    icon: Icons.g_mobiledata_rounded,
                                    onPressed: _handleGoogleSignIn,
                                    color: const Color(0xFFEA4335),
                                    isSocial: true,
                                    isTablet: isTablet,
                                    isLoading: _isLoading,
                                  ),
                                  
                                  const SizedBox(height: 40),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.security_rounded, size: 14, color: AppColors.textTertiary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Secure Cloud Environment',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.textTertiary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context, {
    required String title,
    required VoidCallback onPressed,
    bool isTablet = false,
  }) {
    return Container(
      width: double.infinity,
      height: isTablet ? 72 : 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E1B4B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: isTablet ? 18 : 16,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildCreativeButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isSocial = false,
    bool isTablet = false,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 72 : 64,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: color,
            elevation: 0,
            side: BorderSide(color: color.withOpacity(0.1), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLoading 
                    ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(icon, size: isSocial ? 28 : 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: isTablet ? 18 : 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
