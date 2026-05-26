import 'package:flutter/material.dart';
import 'inventory_categories_screen.dart';

/// Inventory Screen - Main entry point for inventory management
/// Delegates to InventoryCategoriesScreen
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InventoryCategoriesScreen();
  }
}
