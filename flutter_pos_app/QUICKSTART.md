# 🚀 Quick Start Guide - OmniCommerce POS

## Get Running in 3 Steps!

### Step 1: Navigate to Project
```bash
cd "/Users/sumitgupta/omnicommerce copy/flutter_pos_app"
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Run the App
```bash
flutter run
```

---

## First Time User Flow

1. **Splash Screen** (1.5 seconds)
   - Watch the animated logo fade in
   - "OmniCommerce POS" branding
   - Auto-navigates to login

2. **Login Screen**
   - Enter ANY email (e.g., `test@test.com`)
   - Enter ANY password (e.g., `password`)
   - Click "Sign In"
   - 2-second mock authentication delay
   - Navigates to main app

3. **Main App**
   - Bottom navigation with 5 tabs
   - Tap **"POS"** tab (second icon)
   - Experience the full billing system!

---

## Try These Features! 🎯

### Add Products to Cart
1. Browse product grid
2. Click "Add" on any product card
3. See snackbar confirmation
4. Item appears in cart (right side on tablet, bottom on phone)

### Search & Filter
1. Type in search bar: try "rice", "tea", "chips"
2. Click category chips: "Groceries", "Beverages", etc.
3. Watch products filter instantly

### Manage Cart
1. Use +/- buttons to adjust quantity
2. Type quantity directly in text field
3. Click trash icon to remove item
4. See totals update in real-time

### Complete a Sale
1. Add multiple items to cart
2. Review subtotal, tax, total
3. Click "Proceed to Payment"
4. Select payment method (Cash/Card/UPI)
5. For Cash: Enter amount received
6. Watch change calculation
7. Click "Complete Payment"
8. See success dialog with order ID
9. Click "New Sale" to continue

---

## Responsive Design Test

### On Phone (< 600px width):
- Stacked layout
- Products take top portion
- Cart summary at bottom
- Bottom navigation bar

### On Tablet (>= 600px width):
- Split layout
- Products on left (60%)
- Cart panel on right (40%)
- Navigation rail (ready for implementation)

---

## Keyboard Shortcuts (Desktop/Tablet)

- `Ctrl + F` / `Cmd + F`: Focus search field
- `Enter`: Submit forms
- `Escape`: Close dialogs

---

## Troubleshooting

### App Won't Start?
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Hot Reload Not Working?
Press `r` in terminal or use IDE hot reload button

### Want to See Logs?
Check terminal output or use:
```bash
flutter logs
```

---

## What's Included? ✅

### Fully Functional:
- ✅ Splash screen with animation
- ✅ Login/authentication flow (mock)
- ✅ 24 products across 6 categories
- ✅ Product search by name/SKU
- ✅ Category filtering
- ✅ Shopping cart with state management
- ✅ Quantity controls
- ✅ Real-time calculations
- ✅ Payment processing
- ✅ Order success confirmation
- ✅ Responsive design

### Coming Soon (Placeholders):
- 🔄 Dashboard with stats
- 🔄 Orders list and detail
- 🔄 Inventory management
- 🔄 Settings configuration

---

## Demo Script (For Showing to Others)

**1-minute Demo:**
1. Launch app → Show splash animation
2. Login quickly → Mention mock auth
3. Go to POS tab
4. Add 3-4 products to cart
5. Adjust quantities
6. Show live total calculation
7. Proceed to payment
8. Select "Cash"
9. Enter cash amount
10. Show change calculation
11. Complete payment
12. Show success dialog

**Result:** They'll see a professional, production-ready POS system!

---

## Development Tips 💡

### Hot Reload
Make changes to UI code → Press `r` → See instant results!

### Find Something?
All code is in `/lib/` folder:
- Core theme: `/lib/core/theme/`
- POS screen: `/lib/features/pos/presentation/screens/pos_screen.dart`
- Mock data: `/lib/data/datasources/mock_product_data.dart`
- Providers: `/lib/features/pos/providers/`

### Want to Modify?
- Change colors: Edit `/lib/core/theme/app_colors.dart`
- Add products: Edit `/lib/data/datasources/mock_product_data.dart`
- Adjust tax rate: Check `/lib/features/pos/providers/cart_provider.dart`
- Modify layout: Edit `/lib/features/pos/presentation/screens/pos_screen.dart`

---

## Next Steps

### Immediate:
- [ ] Test on physical device
- [ ] Try different screen sizes
- [ ] Add more products if needed

### Optional Enhancements:
- [ ] Build Dashboard screen
- [ ] Create Orders module
- [ ] Add Inventory features
- [ ] Integrate real backend APIs

---

## Need Help?

### Common Issues:

**"No devices found"**
- Connect Android/iOS device
- Or start emulator/simulator
- Or run `flutter devices` to check

**"Build failed"**
- Run `flutter doctor`
- Check Flutter installation
- Ensure all dependencies installed

**UI Looks Different?**
- Hot reload might cache old styles
- Do hot restart (`Shift + R`)
- Or kill app and relaunch

---

## Success Checklist ✅

After running, you should see:
- [ ] Animated splash screen
- [ ] Login form
- [ ] Main app with navigation
- [ ] POS screen with products
- [ ] Working shopping cart
- [ ] Payment dialog
- [ ] Order confirmation

If all checked → **You're ready to go!** 🎉

---

*Happy Coding! 🚀*
