import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/login_role_parser.dart';

/// Normalized role for navigation. Missing / invalid → `unknown` (restrictive; not cashier).
String effectiveUserRole(Map<String, dynamic>? user) {
  final raw =
      user?['role'] ?? user?['userRole'] ?? user?['user_role'];
  final canonical = canonicalUiRole(raw?.toString());
  if (canonical == null) {
    if (kDebugMode) {
      debugPrint(
        '[auth] NAV effectiveUserRole: missing or unrecognized role "$raw" → unknown',
      );
    }
    return 'unknown';
  }
  return canonical;
}

String initialHomeRouteForUser(Map<String, dynamic>? user) {
  switch (effectiveUserRole(user)) {
    case 'super_admin':
      return '/super-admin/dashboard';
    case 'inventory_manager':
      return '/inventory';
    case 'cashier':
      return '/pos';
    case 'customer':
      return '/store';
    default:
      return '/dashboard';
  }
}

/// POS Billing (`/pos`, `/pos/cart`, …) — [admin], [cashier], [inventory_manager].
bool canAccessPosBilling(String role) {
  final r = effectiveUserRole({'role': role});
  return r == 'super_admin' ||
      r == 'admin' ||
      r == 'cashier' ||
      r == 'inventory_manager' ||
      r == 'seo_manager' ||
      r == 'unknown';
}

/// Order list for dashboard charts — backend `GET /orders` is admin + cashier only.
bool canLoadDashboardOrders(String role) {
  final r = effectiveUserRole({'role': role});
  return r == 'super_admin' || r == 'admin' || r == 'cashier';
}

/// Inventory management UIs and mutations — [admin] and [inventory_manager] only.
/// Pass the output of [effectiveUserRole] (or equivalent normalized role).
bool canAccessInventoryManagement(String role) {
  return role == 'super_admin' ||
      role == 'admin' ||
      role == 'inventory_manager' ||
      role == 'seo_manager';
}

/// Staff / role management UI — store [admin] or [super_admin] (not cashier / inventory).
bool canAccessAdminStaffManagement(String role) {
  final r = effectiveUserRole({'role': role});
  return r == 'admin' || r == 'super_admin';
}

/// Whether the current shell location is allowed for [role] (after login).
bool isRouteAllowedForShell(String location, String role) {
  if (location == '/account' || location.startsWith('/account/')) {
    return true;
  }

  if (location == '/admin/staff' || location.startsWith('/admin/')) {
    return canAccessAdminStaffManagement(role);
  }

  if (!canAccessPosBilling(role) &&
      (location == '/pos' || location.startsWith('/pos/'))) {
    return false;
  }

  switch (role) {
    case 'super_admin':
    case 'admin':
      return true;
    case 'cashier':
    case 'unknown':
      if (location == '/dashboard' || location.startsWith('/dashboard/')) {
        return false;
      }
      if (location == '/inventory' || location.startsWith('/inventory/')) {
        return false;
      }
      if (location == '/customers' || location.startsWith('/customers/')) {
        return false;
      }
      return true;
    case 'inventory_manager':
      if (location == '/orders' || location.startsWith('/orders/')) {
        return false;
      }
      if (location.startsWith('/order-detail')) return false;
      if (location == '/customers' || location.startsWith('/customers/')) {
        return false;
      }
      if (location == '/products' || location.startsWith('/products/')) {
        return true;
      }
      return true;
    case 'seo_manager':
      if (location == '/dashboard' || location == '/pos' || location.startsWith('/pos/') || location == '/products' || location.startsWith('/products/') || location == '/inventory' || location.startsWith('/inventory/') || location == '/support' || location.startsWith('/support/') || location == '/settings' || location.startsWith('/settings/')) {
        return true;
      }
      return false;
    default:
      return false;
  }
}

/// Bottom / rail navigation (order matches product spec).
class ShellNavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const ShellNavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

List<ShellNavItem> shellNavItemsForRole(String role) {
  final r = effectiveUserRole({'role': role});

  const dash = ShellNavItem(
    path: '/dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  );
  const pos = ShellNavItem(
    path: '/pos',
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  );
  const orders = ShellNavItem(
    path: '/orders',
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  );
  const inv = ShellNavItem(
    path: '/inventory',
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  );
  const settings = ShellNavItem(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );
  const platform = ShellNavItem(
    path: '/super-admin/dashboard',
    label: 'Platform',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
  );
  const support = ShellNavItem(
    path: '/support',
    label: 'Support',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent,
  );
  const billing = ShellNavItem(
    path: '/billing-history',
    label: 'Billing',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  );
  const allProducts = ShellNavItem(
    path: '/products',
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  );
  const userRole = ShellNavItem(
    path: '/admin/staff',
    label: 'Employees',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
  );
  const customDomain = ShellNavItem(
    path: '/admin/custom-domain',
    label: 'Custom Domain',
    icon: Icons.language_outlined,
    selectedIcon: Icons.language,
  );

  // Explicit per role — cashiers must never see an Inventory tab (no dead-end taps).
  switch (r) {
    case 'super_admin':
      return [dash, pos, billing, allProducts, inv, platform, support, customDomain, userRole, settings];
    case 'admin':
      return [dash, pos, billing, allProducts, inv, support, customDomain, userRole, settings];
    case 'cashier':
    case 'unknown':
      return [pos, orders, support, settings];
    case 'inventory_manager':
      return [dash, pos, allProducts, inv, support, settings];
    case 'seo_manager':
      return [dash, pos, allProducts, inv, support, settings];
    default:
      return [dash, pos, orders, settings];
  }
}

/// True if [location] should highlight the shell tab for [itemPath].
bool shellPathMatchesItem(String location, String itemPath) {
  if (itemPath == '/dashboard') return location == '/dashboard';
  if (itemPath == '/admin/staff') {
    return location == '/admin/staff';
  }
  if (itemPath == '/pos') {
    return location == '/pos' || location.startsWith('/pos/');
  }
  if (itemPath == '/billing-history') {
    return location == '/billing-history' ||
        location.startsWith('/billing-history/') ||
        location == '/orders' ||
        location.startsWith('/orders/') ||
        location.startsWith('/invoices') ||
        location.startsWith('/quotes') ||
        location.startsWith('/order-detail');
  }
  if (itemPath == '/inventory') {
    return location == '/inventory' || location.startsWith('/inventory/');
  }
  if (itemPath == '/settings') {
    return location == '/settings' ||
        location.startsWith('/settings/') ||
        location.startsWith('/admin/');
  }
  if (itemPath == '/super-admin/dashboard') {
    return location == '/super-admin/dashboard' ||
        location.startsWith('/super-admin/');
  }
  if (itemPath == '/support') {
    return location == '/support' || location.startsWith('/support/');
  }
  return false;
}

/// Dashboard drawer / desktop sidebar rows (existing labels).
class DrawerNavItem {
  final String label;
  final IconData icon;
  final String route;

  const DrawerNavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

List<DrawerNavItem> drawerNavItemsForRole(String role) {
  final r = effectiveUserRole({'role': role});

  const dash = DrawerNavItem(
    label: 'Dashboard',
    icon: Icons.grid_view_rounded,
    route: '/dashboard',
  );
  const sales = DrawerNavItem(
    label: 'Sales',
    icon: Icons.point_of_sale_rounded,
    route: '/pos',
  );
  const reports = DrawerNavItem(
    label: 'Reports',
    icon: Icons.bar_chart_rounded,
    route: '/orders',
  );
  const products = DrawerNavItem(
    label: 'Products',
    icon: Icons.inventory_2_rounded,
    route: '/inventory',
  );
  const allProducts = DrawerNavItem(
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    route: '/products',
  );
  const customers = DrawerNavItem(
    label: 'Customers',
    icon: Icons.people_alt_rounded,
    route: '/customers',
  );
  const settings = DrawerNavItem(
    label: 'Settings',
    icon: Icons.settings_rounded,
    route: '/settings',
  );
  const userManagement = DrawerNavItem(
    label: 'Employees',
    icon: Icons.badge_rounded,
    route: '/admin/staff',
  );
  const customDomain = DrawerNavItem(
    label: 'Custom Domain',
    icon: Icons.language_rounded,
    route: '/admin/custom-domain',
  );
  const platform = DrawerNavItem(
    label: 'Platform',
    icon: Icons.admin_panel_settings_rounded,
    route: '/super-admin/dashboard',
  );
  const support = DrawerNavItem(
    label: 'Support Center',
    icon: Icons.support_agent_rounded,
    route: '/support',
  );
  const billing = DrawerNavItem(
    label: 'Billing History',
    icon: Icons.receipt_long_rounded,
    route: '/billing-history',
  );

  switch (r) {
    case 'super_admin':
      return [
        dash,
        sales,
        billing,
        allProducts,
        products,
        customers,
        platform,
        support,
        customDomain,
        userManagement,
        settings,
      ];
    case 'admin':
      return [
        dash,
        sales,
        billing,
        allProducts,
        products,
        customers,
        support,
        customDomain,
        userManagement,
        settings,
      ];
    case 'cashier':
    case 'unknown':
      return [sales, reports, support, settings];
    case 'inventory_manager':
      return [dash, sales, allProducts, products, support, settings];
    case 'seo_manager':
      return [dash, sales, allProducts, products, support, settings];
    default:
      return [dash, sales, reports, support, settings];
  }
}

bool drawerRouteSelected(String location, String route) {
  return shellPathMatchesItem(location, route);
}
