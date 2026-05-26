import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_provider.dart';

/// One held (parked) sale at a time — common retail POS pattern.
class PosHeldCartNotifier extends StateNotifier<CartState?> {
  PosHeldCartNotifier() : super(null);

  void holdSnapshot(CartState cart) {
    if (cart.items.isEmpty) return;
    state = cart.duplicate();
  }

  void discard() {
    state = null;
  }
}

final posHeldCartProvider =
    StateNotifierProvider<PosHeldCartNotifier, CartState?>((ref) {
  return PosHeldCartNotifier();
});
