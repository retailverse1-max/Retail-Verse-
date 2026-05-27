import 'package:flutter/foundation.dart' as fdn;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:retail_verse_pos/features/subscription/presentation/screens/subscription_plans_screen.dart';
import '../core/navigation/role_nav.dart';
import '../core/navigation/role_route_guard.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/signup_screen.dart';
import 'package:retail_verse_pos/features/auth/presentation/screens/onboarding_screen.dart';
import '../features/billing/presentation/screens/subscription_expired_screen.dart';
import '../features/dashboard/providers/dashboard_providers.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/inventory/presentation/screens/all_products_screen.dart';
import '../data/models/product_model.dart';
import '../data/models/order_model.dart';
import '../features/pos/presentation/screens/pos_billing_screen.dart';
import '../features/pos/presentation/screens/pos_cart_screen.dart';
import '../features/pos/presentation/screens/pos_product_detail_screen.dart';
import '../features/pos/presentation/screens/pos_screen.dart';
import '../features/orders/presentation/screens/orders_list_screen.dart';
import '../features/orders/presentation/screens/order_detail_screen.dart';
import '../features/orders/presentation/screens/quote_edit_screen.dart';
import '../features/inventory/presentation/screens/inventory_screen.dart';
import '../features/inventory/presentation/screens/category_products_screen.dart';
import '../features/inventory/presentation/screens/add_product_screen.dart';
import '../features/inventory/data/models/category.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';
import '../features/customers/presentation/screens/customers_screen.dart';
import '../features/admin/presentation/admin_staff_screen.dart';
import '../features/super_admin/presentation/screens/sa_shell.dart';
import '../features/support/presentation/widgets/support_fab.dart';
import '../features/super_admin/presentation/widgets/support_dialog.dart';
import '../features/super_admin/presentation/screens/sa_dashboard_screen.dart';
import '../features/super_admin/presentation/screens/sa_businesses_screen.dart';
import '../features/super_admin/presentation/screens/sa_custom_domains_screen.dart';
import '../features/super_admin/presentation/screens/sa_users_screen.dart';
import '../features/super_admin/presentation/screens/sa_subscriptions_screen.dart';
import '../features/super_admin/presentation/screens/sa_customers_screen.dart';
import '../features/super_admin/presentation/screens/sa_analytics_screen.dart';
import '../features/super_admin/presentation/screens/sa_settings_screen.dart';
import '../features/super_admin/presentation/screens/sa_logs_screen.dart';
import '../features/super_admin/presentation/screens/sa_stores_performance_screen.dart';
import '../features/super_admin/presentation/screens/sa_add_business_screen.dart';
import '../features/super_admin/presentation/screens/sa_business_details_screen.dart';
import '../features/super_admin/presentation/screens/sa_support_chat_screen.dart';
import '../features/super_admin/presentation/screens/sa_contacts_screen.dart';
import '../features/dashboard/presentation/widgets/dashboard_widgets.dart';
import '../features/dashboard/presentation/screens/sales_details_screen.dart';
import '../features/dashboard/presentation/screens/avg_sale_details_screen.dart';
import '../features/customers/presentation/screens/add_customer_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/inventory/presentation/screens/add_category_screen.dart';
import '../features/support/presentation/screens/support_screen.dart';
import '../core/theme/app_colors.dart';

final scaffoldNavigationKey = GlobalKey<ScaffoldState>();

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) {
    final loc = state.uri.path;
    const public = {'/splash', '/login', '/signup', '/onboarding'};
    if (public.contains(loc)) return null;

    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final authState = container.read(authProvider);
      final token = authState.token?.trim();
      final loggedIn = token != null && token.isNotEmpty;
      if (!loggedIn) return '/login';

      final role = authState.user?['role'];
      if (role != 'super_admin' && loc != '/subscription-expired') {
        final expiryStr = authState.user?['subscriptionExpiry'];
        if (expiryStr != null) {
          try {
            final expiryDate = DateTime.parse(expiryStr);
            if (DateTime.now().isAfter(expiryDate)) {
              return '/subscription-expired';
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      // Provider not available yet — stay on splash until ready.
      if (loc == '/splash' || loc == '/login' || loc == '/signup') return null;
      return '/splash';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'];
        return LoginScreen(initialMode: mode);
      },
    ),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/subscription-expired', builder: (context, state) => const SubscriptionExpiredScreen()),

    // Super Admin panel (isolated from POS shell). Visible entry is in Settings for super_admin only.
    ShellRoute(
      builder: (context, state, child) => SuperAdminShell(child: child),
      routes: [
        GoRoute(
          path: '/super-admin/dashboard',
          builder: (context, state) => const SaDashboardScreen(),
        ),
        GoRoute(
          path: '/super-admin/businesses',
          builder: (context, state) => const SaBusinessesScreen(),
        ),
        GoRoute(
          path: '/super-admin/users',
          builder: (context, state) => const SaUsersScreen(),
        ),
        GoRoute(
          path: '/super-admin/customers',
          builder: (context, state) => const SaCustomersScreen(),
        ),
        GoRoute(
          path: '/super-admin/contacts',
          builder: (context, state) => const SaContactsScreen(),
        ),
        GoRoute(
          path: '/super-admin/subscriptions',
          builder: (context, state) => const SaSubscriptionsScreen(),
        ),
        GoRoute(
          path: '/super-admin/analytics',
          builder: (context, state) => const SaAnalyticsScreen(),
        ),
        GoRoute(
          path: '/super-admin/settings',
          builder: (context, state) => const SaSettingsScreen(),
        ),
        GoRoute(
          path: '/super-admin/custom-domains',
          builder: (context, state) => const SaCustomDomainsScreen(),
        ),
        GoRoute(
          path: '/super-admin/support',
          builder: (context, state) => const SaContactsScreen(initialTab: 1),
        ),
        GoRoute(
          path: '/super-admin/logs',
          builder: (context, state) => const SaLogsScreen(),
        ),
        GoRoute(
          path: '/super-admin/orders',
          builder: (context, state) => const OrdersListScreen(),
        ),
        GoRoute(
          path: '/super-admin/stores-performance',
          builder: (context, state) => const SaStoresPerformanceScreen(),
        ),
        GoRoute(
          path: '/super-admin/support-chat',
          builder: (context, state) {
            final params = state.extra as Map<String, dynamic>? ?? {};
            return SaSupportChatScreen(
              ticketSubject: params['subject'] ?? 'Support Request',
              initialMessage: params['message'] ?? '',
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/super-admin/businesses/add',
      builder: (context, state) => const SaAddBusinessScreen(),
    ),
    GoRoute(
      path: '/super-admin/businesses/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return SaBusinessDetailsScreen(businessId: id);
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/inventory/:categoryId',
      pageBuilder: (context, state) {
        final category = state.extra as Category;
        return _guardedShellPage(
          context: context,
          state: state,
          routePath: '/inventory/${state.pathParameters['categoryId'] ?? ''}',
          child: CategoryProductsScreen(category: category),
        );
      },
    ),
    GoRoute(
      path: '/inventory/:categoryId/add-product',
      pageBuilder: (context, state) {
        final category = state.extra as Category?;
        return _guardedShellPage(
          context: context,
          state: state,
          routePath:
              '/inventory/${state.pathParameters['categoryId'] ?? ''}/add-product',
          child: AddProductScreen(category: category),
        );
      },
    ),

    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(
          child: _ShellAccessGate(
            location: state.uri.path,
            child: child,
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/sales-details',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SalesDetailsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/avg-sale-details',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const AvgSaleDetailsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/upgrade',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SubscriptionPlansScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        GoRoute(
          path: '/pos',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const POSScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
          routes: [
            GoRoute(
              path: 'cart',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const PosCartScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
              ),
            ),
            GoRoute(
              path: 'billing',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const PosBillingScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
              ),
            ),
            GoRoute(
              path: 'product',
              pageBuilder: (context, state) {
                final extra = state.extra;
                Product? product;
                void Function(Product, int)? onAddToBilling;
                if (extra is PosBillingProductDetailExtra) {
                  product = extra.product;
                  onAddToBilling = extra.onAdded;
                } else if (extra is Product) {
                  product = extra;
                }
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: product == null
                      ? const _PosProductMissingFallback()
                      : PosProductDetailScreen(
                          product: product,
                          onAddToBilling: onAddToBilling,
                        ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (context, state) => _guardedShellPage(
            context: context,
            state: state,
            routePath: '/products',
            child: const AllProductsScreen(),
          ),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) => _guardedShellPage(
            context: context,
            state: state,
            routePath: '/orders',
            child: const OrdersListScreen(),
          ),
        ),
        GoRoute(
          path: '/billing-history',
          pageBuilder: (context, state) => _guardedShellPage(
            context: context,
            state: state,
            routePath: '/billing-history',
            child: const OrdersListScreen(),
          ),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) => _guardedShellPage(
            context: context,
            state: state,
            routePath: '/inventory',
            child: const InventoryScreen(),
          ),
        ),
        GoRoute(
          path: '/inventory/categories/add',
          pageBuilder: (context, state) => _guardedShellPage(
            context: context,
            state: state,
            routePath: '/inventory/categories/add',
            child: const AddCategoryScreen(),
          ),
        ),

        GoRoute(
          path: '/customers',
          pageBuilder: (context, state) {
            final select = state.uri.queryParameters['select'] == 'true';
            final name = state.uri.queryParameters['name'];
            final phone = state.uri.queryParameters['phone'];
            final address = state.uri.queryParameters['address'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: CustomersScreen(
                isSelectionMode: select,
                initialName: name,
                initialPhone: phone,
                initialAddress: address,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
        GoRoute(
          path: '/add-customer',
          pageBuilder: (context, state) {
            final name = state.uri.queryParameters['name'];
            final phone = state.uri.queryParameters['phone'];
            final address = state.uri.queryParameters['address'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: AddCustomerScreen(
                initialName: name,
                initialPhone: phone,
                initialAddress: address,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
            );
          },
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/support',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: SupportScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        GoRoute(
          path: '/admin/staff',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const AdminStaffScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/admin/custom-domain',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SaCustomDomainsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/account',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const AccountScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        ),
        GoRoute(
          path: '/order-detail/:id',
          pageBuilder: (context, state) {
            final order = state.extra as dynamic;
            return CustomTransitionPage(
              key: state.pageKey,
              child: OrderDetailScreen(order: order),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
        GoRoute(
          path: '/orders/:id',
          pageBuilder: (context, state) {
            final order = state.extra as dynamic;
            return CustomTransitionPage(
              key: state.pageKey,
              child: OrderDetailScreen(order: order),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
        GoRoute(
          path: '/quotes/edit/:id',
          pageBuilder: (context, state) {
            final order = state.extra as Order;
            return CustomTransitionPage(
              key: state.pageKey,
              child: QuoteEditScreen(order: order),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            );
          },
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _guardedShellPage({
  required BuildContext context,
  required GoRouterState state,
  required String routePath,
  required Widget child,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final role = effectiveUserRole(container.read(authProvider).user);
  final allowed = isRouteAllowedForShell(routePath, role);
  return CustomTransitionPage(
    key: state.pageKey,
    child: allowed
        ? child
        : RoleAccessDeniedView(
            onGoHome: () => context.go('/dashboard'),
          ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Shown when `/pos/product` is opened without `extra` (deep link / bad navigation).
class _PosProductMissingFallback extends StatelessWidget {
  const _PosProductMissingFallback();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('No product selected.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/pos'),
                child: const Text('Back to products'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellAccessGate extends ConsumerWidget {
  const _ShellAccessGate({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = effectiveUserRole(ref.watch(authProvider).user);
    if (isRouteAllowedForShell(location, role)) {
      return child;
    }
    return RoleAccessDeniedView(onGoHome: () => context.go('/dashboard'));
  }
}

final sidebarPinnedProvider = StateProvider<bool>((ref) => false);

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    final role = effectiveUserRole(ref.read(authProvider).user);

    if (!isRouteAllowedForShell(location, role)) {
      _selectedIndex = 0;
      return;
    }

    final items = shellNavItemsForRole(role);
    var idx = 0;
    for (var i = 0; i < items.length; i++) {
      if (shellPathMatchesItem(location, items[i].path)) {
        idx = i;
        break;
      }
    }
    _selectedIndex = idx.clamp(0, items.length - 1);
  }

  void _onItemTapped(int index, List<ShellNavItem> items) {
    if (index < 0 || index >= items.length) return;
    
    final item = items[index];
    if (item.path == '/support') {
      final role = effectiveUserRole(ref.read(authProvider).user);
      if (role != 'admin' && role != 'super_admin') {
        showDialog(context: context, builder: (c) => const SupportDialog());
        return;
      }
    }
    
    setState(() => _selectedIndex = index);
    context.go(item.path);
  }

  @override
  Widget build(BuildContext context) {
    final role = effectiveUserRole(ref.watch(authProvider).user);
    if (fdn.kDebugMode) {
      final path = GoRouterState.of(context).uri.path;
      fdn.debugPrint('[auth] NAV ROLE (MainLayout): $role path=$path');
    }
    final items = shellNavItemsForRole(role);
    final safeIndex = _selectedIndex.clamp(0, items.length - 1);
    
    final size = MediaQuery.of(context).size;
    final isTabletWidth = size.width >= 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    final path = GoRouterState.of(context).uri.path;
    final isPosScreen = path == '/pos' || path.startsWith('/pos/');

    // Sidebar can only be pinned on tablet width in landscape orientation
    final canPinSidebar = isTabletWidth && isLandscape;
    final isPinned = ref.watch(sidebarPinnedProvider);
    final showPinnedSidebar = canPinSidebar && isPinned;

    final user = ref.watch(authProvider).user;
    final userName = user?['name']?.toString();
    final userEmail = user?['email']?.toString();

    final sidebar = PremiumAdminSidebar(
      selectedIndex: safeIndex,
      isPinned: showPinnedSidebar,
      onToggleCollapse: canPinSidebar ? () {
        if (!showPinnedSidebar) {
          // If we are currently unpinned and clicking this button (inside the drawer),
          // we want to close the drawer before pinning it back to the screen.
          if (scaffoldNavigationKey.currentState?.isDrawerOpen ?? false) {
            Navigator.of(context).pop(); 
          }
        }
        ref.read(sidebarPinnedProvider.notifier).state = !isPinned;
      } : null,
      onDestinationSelected: (i) {
        _onItemTapped(i, items);
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Close drawer
      },
      items: [
        for (final it in items)
          PremiumNavItem(
            label: it.label,
            icon: it.icon,
            selectedIcon: it.selectedIcon,
          ),
      ],
      userName: userName,
      userEmail: userEmail,
    );

    final statsAsync = ref.watch(dashboardStatsProvider);
    final productsAsync = ref.watch(dashboardProductsProvider);
    final ordersAsync = ref.watch(dashboardOrdersProvider);
    final isInitialLoading = (statsAsync.isLoading && !statsAsync.hasValue) ||
                             (productsAsync.isLoading && !productsAsync.hasValue) ||
                             (ordersAsync.isLoading && !ordersAsync.hasValue);

    final showFab = !(path == '/dashboard' && isInitialLoading);

    final body = Scaffold(
      key: scaffoldNavigationKey,
      drawer: showPinnedSidebar ? null : Drawer(
        width: 280,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: sidebar,
      ),
      extendBody: true,
      floatingActionButton: showFab ? const BlinkingSupportFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          Row(
            children: [
              if (showPinnedSidebar)
                SizedBox(
                  width: 280,
                  child: sidebar,
                ),
              Expanded(child: widget.child),
            ],
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) return;

        // 1. Close active drawer
        if (scaffoldNavigationKey.currentState?.isDrawerOpen ?? false) {
          scaffoldNavigationKey.currentState?.closeDrawer();
          return;
        }

        // 2. Standard Navigator pop (Dialogs, Modals, pushed routes)
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        // 3. GoRouter specific pop
        try {
          if (context.canPop()) {
            context.pop();
            return;
          }
        } catch (_) {}

        // 4. Intelligence: Logical Parent Navigation
        final uri = GoRouterState.of(context).uri;
        final currentPath = uri.path;
        final segments = currentPath.split('/').where((s) => s.isNotEmpty).toList();
        
        if (segments.length > 1) {
          String parentPath = '/' + segments.take(segments.length - 1).join('/');
          
          // Handle dashboard alias
          if (parentPath == '/super-admin') {
            parentPath = '/super-admin/dashboard';
          }
          
          if (parentPath != currentPath) {
            context.go(parentPath);
            return;
          }
        }

        // 5. Root Handling: Role-based Home
        final user = ref.read(authProvider).user;
        final home = initialHomeRouteForUser(user);
        
        if (currentPath != home) {
          context.go(home);
          return;
        }

        SystemNavigator.pop();
      },
      child: body,
    );
  }

  Widget _buildVerticalNavRail({
    required int selectedIndex,
    required List<ShellNavItem> items,
    required ValueChanged<int> onDestinationSelected,
    String? role,
  }) {
    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: AppColors.accent, // Dark Blue
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 60),
          if (role != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: RotatedBox(
                quarterTurns: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final isSelected = selectedIndex == i;
                return InkWell(
                  onTap: () => onDestinationSelected(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                      border: isSelected 
                        ? Border(left: BorderSide(color: AppColors.primary, width: 4))
                        : null,
                    ),
                    child: Icon(
                      isSelected ? items[i].selectedIcon : items[i].icon,
                      color: isSelected ? AppColors.primary : Colors.white70,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
