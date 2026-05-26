class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String billingCycle;
  final List<String> features;
  final int maxProducts;
  final int maxUsers;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.billingCycle,
    required this.features,
    required this.maxProducts,
    required this.maxUsers,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      billingCycle: json['billingCycle'] ?? 'monthly',
      features: List<String>.from(json['features'] ?? []),
      maxProducts: json['maxProducts'] ?? 100,
      maxUsers: json['maxUsers'] ?? 5,
    );
  }
}
