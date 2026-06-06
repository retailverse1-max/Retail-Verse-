import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/role_nav.dart';
import '../../../../core/utils/validators.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../providers/auth_provider.dart';
import '../../../../data/remote/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'package:country_code_picker/country_code_picker.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  const LoginScreen({super.key, this.initialMode});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isLocalLoading = false;
  bool _useOtp = false;
  bool _otpSent = false;
  String _selectedCountryCode = '+91';
  
  Timer? _otpTimer;
  int _otpCountdown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode == 'otp') {
      _useOtp = true;
    }
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _startOtpTimer() {
    setState(() {
      _otpCountdown = 30;
      _otpSent = true;
    });
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCountdown > 0) {
        setState(() {
          _otpCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_useOtp && _otpController.text.length < 6) {
      _showErrorSnackBar('Please enter valid 6-digit OTP');
      return;
    }
    if (_isLocalLoading) return;

    setState(() {
      _isLocalLoading = true;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      authNotifier.clearError();

      final success = _useOtp
          ? await authNotifier.verifyOtp(
              phone: '$_selectedCountryCode${_phoneController.text.trim()}',
              otp: _otpController.text.trim(),
            )
          : await authNotifier.login(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

      if (!mounted) return;

      if (success) {
        // Stop loader immediately before navigating
        setState(() => _isLocalLoading = false);
        invalidateAllDashboardProviders(ref);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final home = initialHomeRouteForUser(ref.read(authProvider).user);
        context.go(home); // Use go instead of push to clear login from stack
      } else {
        final error = ref.read(authProvider).error;
        _showErrorSnackBar(error ?? 'Invalid email or password');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email first to reset password');
      return;
    }

    setState(() => _isLocalLoading = true);
    try {
      await AuthService().forgotPassword(email: email);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your email. Please check your inbox.'), backgroundColor: Colors.green),
      );
      
      _showResetPasswordDialog(email);
    } catch (e) {
      _showErrorSnackBar('Failed to send reset email: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLocalLoading = false);
    }
  }

  void _showResetPasswordDialog(String email) {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Reset Password', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Enter the 6-digit OTP sent to $email and your new password.', style: AppTypography.bodySmall),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '6-digit OTP',
                        prefixIcon: const Icon(Icons.pin_rounded),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Enter valid OTP' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isResetting ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setDialogState(() => isResetting = true);
                    try {
                      await AuthService().resetPassword(
                        email: email,
                        otp: otpController.text.trim(),
                        newPassword: newPasswordController.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password reset successfully! Please log in.'), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                      );
                    } finally {
                      if (mounted) setDialogState(() => isResetting = false);
                    }
                  },
                  child: isResetting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '127152555107-mo61lp114l0e25128696iud0e0ul2q65.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCred.user != null) {
        // Update AuthProvider state to sync with session
        await ref.read(authProvider.notifier).signInWithGoogle(userCred.user!);
        _showSuccessAndNavigate('Google Sign-In successful');
      }
    } catch (e) {
      _showErrorSnackBar('Google Sign-In failed: $e');
    }
  }

  void _showSuccessAndNavigate(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
    context.go('/dashboard');
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    if (_isLocalLoading) return;
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Phone number is required');
      return;
    }
    final phoneError = AppValidators.validatePhone(_phoneController.text.trim());
    if (phoneError != null) {
      _showErrorSnackBar(phoneError);
      return;
    }

    setState(() => _isLocalLoading = true);
    try {
      final ok = await ref
          .read(authProvider.notifier)
          .sendOtp(phone: '$_selectedCountryCode${_phoneController.text.trim()}');
      if (!mounted) return;
      if (ok) {
        _startOtpTimer();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP sent'),
            backgroundColor: const Color(0xFF163F6B),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        FocusScope.of(context).requestFocus(_otpFocusNode);
      } else {
        final error = ref.read(authProvider).error;
        _showErrorSnackBar(error ?? 'Failed to send OTP');
      }
    } finally {
      if (mounted) setState(() => _isLocalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLocalLoading || authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── PREMIUM DARK HEADER ────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 40, 24, 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(48),
                    bottomRight: Radius.circular(48),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Retail Verse',
                      style: AppTypography.displaySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The pulse of your business',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── LOGIN FORM CARD ─────────────────────────────
              Transform.translate(
                offset: const Offset(0, -30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please sign in to continue',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Login Mode Toggle
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                _buildModeToggle(label: 'Email', isActive: !_useOtp, onTap: () => setState(() { _useOtp = false; _otpSent = false; })),
                                _buildModeToggle(
                                  label: 'Phone OTP', 
                                  isActive: _useOtp, 
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Phone OTP login is coming soon!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (!_useOtp) ...[
                            _AuthInputField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              hint: 'Email Address',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: AppValidators.validateEmail,
                            ),
                            const SizedBox(height: 16),
                            _AuthInputField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              hint: 'Password',
                              icon: Icons.key_rounded,
                              obscureText: _obscurePassword,
                              validator: AppValidators.validatePassword,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _handleForgotPassword,
                                child: Text('Forgot Password?', style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else ...[
                            _AuthInputField(
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              hint: 'Phone Number',
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                              prefixWidget: CountryCodePicker(
                                onChanged: (code) => _selectedCountryCode = code.dialCode ?? '+91',
                                initialSelection: 'IN',
                                favorite: const ['+91', 'IN'],
                                showCountryOnly: false,
                                showOnlyCountryWhenClosed: false,
                                alignLeft: false,
                                padding: EdgeInsets.zero,
                                textStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                              ),
                              validator: (v) => _useOtp ? AppValidators.validatePhone(v) : null,
                              suffixIcon: TextButton(
                                onPressed: (_otpCountdown > 0 || isLoading) ? null : _handleSendOtp,
                                child: Text(_otpCountdown > 0 ? '${_otpCountdown}s' : 'Get OTP', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 24),
                              Center(
                                child: Pinput(
                                  length: 6,
                                  controller: _otpController,
                                  focusNode: _otpFocusNode,
                                  defaultPinTheme: PinTheme(
                                    width: 45,
                                    height: 52,
                                    textStyle: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.transparent),
                                    ),
                                  ),
                                  focusedPinTheme: PinTheme(
                                    width: 45,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primary, width: 2),
                                    ),
                                  ),
                                  onCompleted: (_) => _handleLogin(),
                                ),
                              ),
                            ],
                          ],

                          const SizedBox(height: 32),
                          SizedBox(
                            height: 58,
                            child: FilledButton(
                              onPressed: isLoading ? null : _handleLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.3),
                              ),
                              child: isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── SOCIAL LOGIN & FOOTER ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR CONTINUE WITH', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, letterSpacing: 1)),
                        ),
                        Expanded(child: Divider(color: AppColors.divider)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialButton(icon: Icons.g_mobiledata_rounded, color: const Color(0xFFDB4437), onTap: _handleGoogleSignIn),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("New to Retail Verse? ", style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        GestureDetector(
                          onTap: () => context.push('/signup'),
                          child: Text('Create Account', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Server: ${ApiEndpoints.baseUrl}',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary.withOpacity(0.5), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle({required String label, required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixWidget;

  const _AuthInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.prefixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
        prefixIcon: prefixWidget ?? Icon(icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFF312E81), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 56,
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
