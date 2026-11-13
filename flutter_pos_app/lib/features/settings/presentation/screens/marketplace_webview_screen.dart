import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';

class MarketplaceWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final Color brandColor;

  const MarketplaceWebViewScreen({
    super.key,
    required this.title,
    required this.url,
    required this.brandColor,
  });

  @override
  State<MarketplaceWebViewScreen> createState() => _MarketplaceWebViewScreenState();
}

class _MarketplaceWebViewScreenState extends State<MarketplaceWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _isLoading = true;
  bool _loginDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _loadingProgress = 100;
              });
              _checkAutoLogin(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _checkAutoLogin(String url) async {
    final uri = Uri.tryParse(url);
    final path = uri?.path.toLowerCase() ?? '';
    final fragment = uri?.fragment.toLowerCase() ?? '';

    if (path.contains('dashboard') ||
        path.contains('hub') ||
        path.contains('portal') ||
        fragment.contains('dashboard') ||
        fragment.contains('home')) {
      if (mounted) {
        setState(() => _loginDetected = true);
      }
    }
  }

  Future<void> _handleConfirmLogin() async {
    try {
      final currentUrl = await _controller.currentUrl() ?? '';
      final uri = Uri.tryParse(currentUrl);
      final path = uri?.path.toLowerCase() ?? '';
      final fragment = uri?.fragment.toLowerCase() ?? '';

      final isDashboardUrl = path.contains('dashboard') ||
          path.contains('home') ||
          path.contains('hub') ||
          path.contains('portal') ||
          path.contains('panel') ||
          fragment.contains('dashboard') ||
          fragment.contains('home');

      String pageEvaluation = '';
      try {
        final result = await _controller.runJavaScriptReturningResult('''
          (function() {
            try {
              var text = (document.body ? document.body.innerText : '').toLowerCase();
              var hasLoggedInEvidence = text.includes('logout') || text.includes('sign out') || text.includes('my dashboard') || text.includes('seller id') || text.includes('my account') || document.querySelector('[href*="logout"], [aria-label*="logout"], .logout') !== null;
              var isLandingPage = text.includes('start selling') || text.includes('enter mobile number') || text.includes('create account') || text.includes('register as a seller');
              if (hasLoggedInEvidence) return "LOGGED_IN";
              if (isLandingPage) return "NOT_LOGGED_IN";
              return "UNKNOWN";
            } catch(e) {
              return "ERROR";
            }
          })()
        ''');
        pageEvaluation = result.toString().replaceAll('"', '').trim();
      } catch (_) {}

      // If user hasn't logged in yet and is still on the landing/login page
      if (!isDashboardUrl && pageEvaluation == "NOT_LOGGED_IN") {
        if (!mounted) return;
        _showNotLoggedInWarning();
        return;
      }

      // Login validated
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      // In case of error evaluating script, proceed
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showNotLoggedInWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 10),
            Text('Login Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        content: const Text(
          'You are not logged in to your seller account yet.\n\nPlease enter your Mobile Number or Email on the portal and complete your login or registration first to authorize live product sync.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Handled naturally: pops with false/null if user backed out
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context, false),
          ),
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.brandColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              tooltip: 'Reload',
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress / 100 : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.brandColor),
                  ),
                )
              : null,
        ),
        body: Column(
          children: [
            if (_loginDetected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF0FDF4),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seller Dashboard detected! Tap "I\'ve Logged In" below to complete sync.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logged in on the portal?',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to complete sync',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _handleConfirmLogin,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    "I've Logged In",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
