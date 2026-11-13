sed -i '' '/_buildTotalRow(.Tax (18%)/a\
          if (order.extraCharges > 0) ...[\
            const SizedBox(height: 8),\
            _buildTotalRow(\
              '\''Extra Charges'\'',\
              '\''+${AppFormatters.formatCurrency(order.extraCharges)}'\'',\
            ),\
          ],
' lib/features/orders/presentation/screens/order_detail_screen.dart
