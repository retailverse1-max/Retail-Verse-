sed -i '' 's/ordersAsync.when(/ordersAsync.when(\
                      skipLoadingOnReload: true,\
                      skipLoadingOnRefresh: true,/' lib/features/orders/presentation/screens/orders_list_screen.dart
