import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retail_verse_pos/core/theme/app_colors.dart';
import 'package:retail_verse_pos/core/theme/app_typography.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../subscription/data/repositories/subscription_repository.dart';
import '../../../subscription/data/models/subscription_plan.dart';
import '../../../core/navigation/role_nav.dart';

class TrialBanner extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;

  const TrialBanner({super.key, required this.user});

  @override
  ConsumerState<TrialBanner> createState() => _TrialBannerState();
}

class _TrialBannerState extends ConsumerState<TrialBanner> {
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      
      int totalPages = 3; // Trial status + Basic + Premium
      _currentPage = (_currentPage + 1) % totalPages;
      
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = effectiveUserRole(widget.user);
    if (role != 'admin' && role != 'super_admin') {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // If not a trial, hide the banner
    if (widget.user['subscriptionPlan'] != 'trial') {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final expiryString = widget.user['subscriptionExpiry'];
    if (expiryString == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final expiryDate = DateTime.tryParse(expiryString);
    if (expiryDate == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    final daysLeft = difference.inDays;

    if (daysLeft < 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isUrgent = daysLeft <= 3;
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return SliverToBoxAdapter(
      child: plansAsync.when(
        loading: () => _buildLoadingBanner(),
        error: (err, _) => _buildLocalCarousel(daysLeft, isUrgent, null),
        data: (plans) => _buildLocalCarousel(daysLeft, isUrgent, plans),
      ),
    );
  }

  Widget _buildLoadingBanner() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLocalCarousel(int daysLeft, bool isUrgent, List<SubscriptionPlan>? plans) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 750;
    final isTablet = width >= 750 && width < 1000;
    final height = isMobile ? 160.0 : (isTablet ? 120.0 : 110.0);

    // We build 3 slides: Trial Info, Plus/Basic Plan, Premium Plan
    final List<Widget> slides = [
      _buildTrialSlide(daysLeft, isUrgent, isMobile),
      _buildPlanSlide(
        title: 'Plus Plan',
        price: plans != null && plans.isNotEmpty ? '₹${plans[0].price.toInt()}' : '₹999',
        features: plans != null && plans.isNotEmpty 
            ? plans[0].features.take(3).join(' • ')
            : 'Max 100 Products • 5 Staff Users • Basic Analytics',
        gradientColors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
        icon: FontAwesomeIcons.rocket,
        isMobile: isMobile,
      ),
      _buildPlanSlide(
        title: 'Premium Plan',
        price: plans != null && plans.length > 1 ? '₹${plans[1].price.toInt()}' : '₹1999',
        features: plans != null && plans.length > 1
            ? plans[1].features.take(3).join(' • ')
            : 'Unlimited Products • Unlimited Staff • Multi-Store POS',
        gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        icon: FontAwesomeIcons.crown,
        isMobile: isMobile,
      ),
    ];

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: slides,
            ),
            // Slide indicator dots
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(_currentPage == index ? 0.9 : 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialSlide(int daysLeft, bool isUrgent, bool isMobile) {
    final gradient = isUrgent
        ? const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.only(left: 20, top: 16, right: 20, bottom: 28),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.clock, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUrgent ? 'Trial Expiring Soon!' : 'Free Trial Active',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'You have $daysLeft days left in your free trial.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => context.push('/upgrade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.zero,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Upgrade Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 18,
                                color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.clock, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isUrgent ? 'Trial Expiring Soon!' : 'Free Trial Active',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You have $daysLeft days left in your free trial. Subscribe to keep using the app.',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 0,
                  child: ElevatedButton(
                    onPressed: () => context.push('/upgrade'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Upgrade Now',
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 18,
                          color: isUrgent ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlanSlide({
    required String title,
    required String price,
    required String features,
    required List<Color> gradientColors,
    required IconData icon,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.only(left: 20, top: 16, right: 20, bottom: 28),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          FaIcon(icon, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$price/mo',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  features,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => context.push('/upgrade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white, width: 1),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'View Plan',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$price/mo',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        features,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 0,
                  child: ElevatedButton(
                    onPressed: () => context.push('/upgrade'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'View Plan',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
