sed -i '' '/orderNotes: order.notes,/a\
      extraCharges: order.extraCharges,
' lib/features/orders/presentation/screens/order_detail_screen.dart

sed -i '' '/orderNotes: quote.notes,/a\
      extraCharges: quote.extraCharges,
' lib/features/orders/presentation/widgets/quote_details_modal.dart

sed -i '' '/ref.invalidate(ordersListProvider);/a\
      try { ref.invalidate(saOrdersListProvider); } catch (_) {}\
' lib/features/pos/providers/order_providers.dart
