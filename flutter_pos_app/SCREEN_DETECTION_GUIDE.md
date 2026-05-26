# 📊 Screen Detection & Logging - Usage Guide

## ✅ Created Utility

**File:** `lib/core/utils/screen_detector.dart`

This utility automatically detects and logs complete screen information for responsive design testing.

---

## 🚀 How to Use

### **Method 1: One-Line Detection in Any Screen**

Add this to any screen's `build()` method:

```dart
@override
Widget build(BuildContext context) {
  // Log screen info to console
  ScreenDetector.logScreenInfo(context);
  
  // Rest of your build code...
  return Scaffold(...);
}
```

### **Method 2: Get Layout Configuration**

```dart
@override
Widget build(BuildContext context) {
  final config = ScreenDetector.getLayoutConfig(context);
  
  print('Is Mobile: ${config['isMobile']}');
  print('Columns: ${config['crossAxisCount']}');
  print('Card Width: ${config['cardWidth']}');
  
  return Scaffold(...);
}
```

### **Method 3: Conditional Layouts**

```dart
@override
Widget build(BuildContext context) {
  if (ScreenDetector.isMobile(context)) {
    // Mobile-specific layout
    return _buildMobileLayout();
  } else if (ScreenDetector.isTablet(context)) {
    // Tablet layout
    return _buildTabletLayout();
  } else {
    // Desktop layout
    return _buildDesktopLayout();
  }
}
```

---

## 📋 Example Output in Console

When you run the app, you'll see detailed logs like this:

```
╔═══════════════════════════════════════════════════════════╗
║                    📊 SCREEN DETECTION                     ║
╠═══════════════════════════════════════════════════════════╣
║  Device Type: 📱 MOBILE
║  Breakpoint: Small (Standard Phone)
╠───────────────────────────────────────────────────────────╢
║  Dimensions:
║  • Width:  393.00 px
║  • Height: 873.00 px
║  • Aspect Ratio: 0.45
╠───────────────────────────────────────────────────────────╢
║  Display Properties:
║  • Pixel Ratio: 3.00x
║  • Orientation: Portrait ↕️
║  • Safe Area Top: 47 px
║  • Safe Area Bottom: 34 px
╠───────────────────────────────────────────────────────────╢
║  Responsive Layout Recommendations:
║  • Grid Columns: 2
║  • Card Width: 172.50 px
║  • Use 2 columns for inventory grid
╠───────────────────────────────────────────────────────────╢
║  Keyboard State: ⌨️ CLOSED
╚═══════════════════════════════════════════════════════════╝
```

---

## 🔧 Add to Your Existing Screens

### **Example: Inventory Categories Screen**

Edit: `lib/features/inventory/presentation/screens/inventory_categories_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  // ADD THIS LINE - Log screen info
  ScreenDetector.logScreenInfo(context);
  
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth >= 900;
  
  // ... rest of existing code
  return Scaffold(...);
}
```

### **Example: Category Products Screen**

Edit: `lib/features/inventory/presentation/screens/category_products_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  // Auto-detect and log
  ScreenDetector.logScreenInfo(context);
  
  // Or get config for smart layout
  final config = ScreenDetector.getLayoutConfig(context);
  final columnCount = config['crossAxisCount'] as int;
  
  // Use in GridView
  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnCount,
      // ...
    ),
  );
}
```

---

## 📱 Test on Different Devices

### **Run on Various Screen Sizes:**

```bash
# Run on real device
flutter run

# Run on specific emulator size
flutter run -d emulator-5554

# Run with specific dimensions
flutter run --device-id=emulator-5554 --dart-define=SCREEN_WIDTH=768
```

### **Use Flutter DevTools:**

1. Run app: `flutter run`
2. Open DevTools: Press `p` in terminal or go to `http://localhost:9100`
3. Select "Inspector" tab
4. See screen metrics under "MediaQuery"

---

## 🎯 Quick Reference - Breakpoints

| Width Range | Device Type | Columns | Use Case |
|-------------|-------------|---------|----------|
| < 375px | Extra Small | 2 | Compact phones |
| 375-600px | Mobile | 2 | Standard phones |
| 600-900px | Tablet (Small) | 3 | Phablets, small tablets |
| 900-1200px | Tablet (Large) | 4 | Standard tablets |
| > 1200px | Desktop | 4+ | Large tablets, desktops |

---

## 🔍 What Gets Logged

Every time the screen builds, you'll see:

✅ **Device Type**: Mobile/Tablet/Desktop  
✅ **Breakpoint**: Exact size category  
✅ **Dimensions**: Width × Height in pixels  
✅ **Aspect Ratio**: Width/Height ratio  
✅ **Pixel Ratio**: Device pixel density  
✅ **Orientation**: Portrait/Landscape  
✅ **Safe Areas**: Notch/home indicator padding  
✅ **Keyboard State**: Open/Closed with height  
✅ **Layout Recommendations**: Smart suggestions  

---

## 💡 Pro Tips

### **1. Auto-Log on First Build Only**

```dart
bool _hasLogged = false;

@override
Widget build(BuildContext context) {
  if (!_hasLogged) {
    ScreenDetector.logScreenInfo(context);
    _hasLogged = true;
  }
  // ...
}
```

### **2. Log When Orientation Changes**

```dart
Orientation? _previousOrientation;

@override
Widget build(BuildContext context) {
  final orientation = MediaQuery.of(context).orientation;
  
  if (_previousOrientation != orientation) {
    ScreenDetector.logScreenInfo(context);
    _previousOrientation = orientation;
  }
  // ...
}
```

### **3. Test All Breakpoints**

Use Flutter's responsive preview:

```bash
# In VS Code or Android Studio
# Use Device Preview or Screen Size widgets
```

---

## 🛠️ Debug Common Issues

### **Issue: Cards Overflowing**

Check logged card width:
```
• Card Width: 172.50 px
```

If too wide, reduce margins or increase columns.

### **Issue: Too Much Empty Space**

Check recommended columns:
```
• Grid Columns: 2
```

Consider using 3 columns for widths > 600px.

### **Issue: Keyboard Covering Input**

Check keyboard state:
```
• Keyboard State: 🔑 OPEN (300 px)
```

Use `SingleChildScrollView` when keyboard is open.

---

## ✅ Complete Example

Here's a complete screen using the detector:

```dart
import 'package:flutter/material.dart';
import '../../../../core/utils/screen_detector.dart';

class MyResponsiveScreen extends StatelessWidget {
  const MyResponsiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Log screen info automatically
    ScreenDetector.logScreenInfo(context);
    
    // Get smart configuration
    final config = ScreenDetector.getLayoutConfig(context);
    final isMobile = config['isMobile'] as bool;
    final columns = config['crossAxisCount'] as int;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'Mobile View' : 'Desktop View'),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 0.85,
        ),
        itemCount: 20,
        itemBuilder: (context, index) => Card(child: Center(child: Text('Item $index'))),
      ),
    );
  }
}
```

---

## 🎉 You're Ready!

Just add `ScreenDetector.logScreenInfo(context);` to any screen and check your console!

The utility will help you:
- ✅ Debug responsive layouts
- ✅ Test different screen sizes
- ✅ Verify breakpoints work correctly
- ✅ Optimize card/grid sizes
- ✅ Handle keyboard properly

Happy responsive designing! 📱📱💻

---

*Generated on: April 3, 2026*  
*OmniCommerce POS - Screen Detection Utility*
