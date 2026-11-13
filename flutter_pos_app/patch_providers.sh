sed -i '' 's/final ordersListProvider = FutureProvider<List<Order>>((ref) async {/class OrdersListNotifier extends AsyncNotifier<List<Order>> {\
  @override\
  Future<List<Order>> build() async {/' lib/features/pos/providers/order_providers.dart
