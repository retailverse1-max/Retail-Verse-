/// Category model for inventory management
class Category {
  final String id;
  final String name;
  final String subtitle;
  final String imagePath;
  final int productCount;

  const Category({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.imagePath,
    required this.productCount,
  });

  /// Create sample categories for demo
  static List<Category> getSampleCategories() {
    return [
      Category(
        id: '1',
        name: 'Central Components',
        subtitle: '12 products',
        imagePath: 'assets/icons/cpu.png',
        productCount: 12,
      ),
      Category(
        id: '2',
        name: 'Peripherals',
        subtitle: '8 products',
        imagePath: 'assets/icons/peripheral.png',
        productCount: 8,
      ),
      Category(
        id: '3',
        name: 'Connectors',
        subtitle: '15 products',
        imagePath: 'assets/icons/connector.png',
        productCount: 15,
      ),
      Category(
        id: '4',
        name: 'Body',
        subtitle: '6 products',
        imagePath: 'assets/icons/body.png',
        productCount: 6,
      ),
      Category(
        id: '5',
        name: 'Sensors',
        subtitle: '10 products',
        imagePath: 'assets/icons/sensor.png',
        productCount: 10,
      ),
      Category(
        id: '6',
        name: 'Tools',
        subtitle: '9 products',
        imagePath: 'assets/icons/tools.png',
        productCount: 9,
      ),
    ];
  }
}
