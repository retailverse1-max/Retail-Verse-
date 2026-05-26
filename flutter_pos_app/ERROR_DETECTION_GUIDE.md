# 🐛 Error Detection & Auto-Logging System

## ✅ What Was Created

**New File:** `lib/core/utils/error_detector.dart`

A comprehensive error detection system that automatically catches, logs, and helps debug errors on your physical device.

---

## 🚀 How It Works

### **Automatic Error Catching:**

Once enabled, the system automatically detects:

✅ **Flutter Framework Errors** - Widget build errors, layout issues  
✅ **Async Errors** - Failed Futures, Stream errors  
✅ **Network Errors** - API connection failures  
✅ **Null Errors** - Null pointer exceptions  
✅ **Type Errors** - Invalid type casting  
✅ **Render Errors** - UI overflow, layout issues  
✅ **Permission Errors** - Camera, storage denied  

### **Detailed Error Logs:**

When an error occurs, you'll see in console:

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ ASYNC ERROR DETECTED                 
╠═══════════════════════════════════════════════════════════╣
║  Time: 2026-04-03T10:30:45.123456
╠───────────────────────────────────────────────────────────╢
║  Error Type: SocketException
║  Message: Connection refused (OS Error: Connection refused)
╠───────────────────────────────────────────────────────────╢
║  Stack Trace:
║  #0      _NativeSocket.startConnect (dart:io-patch/socket_patch.dart)
║  #1      NetworkConnection.connect (package:app/network.dart:45)
║  #2      ApiService.getProducts (package:app/api.dart:23)
║  ═══════════════════════════════════════════════════════════
╚═══════════════════════════════════════════════════════════╝
```

---

## 📋 Already Integrated!

The error detector is **automatically enabled** in your app's `main.dart`.

You don't need to do anything else - it will catch all errors globally!

---

## 🔍 What Gets Logged

Every error includes:

| Field | Description |
|-------|-------------|
| **Time** | Exact timestamp when error occurred |
| **Error Type** | Exception class (e.g., `SocketException`) |
| **Message** | Human-readable error description |
| **Stack Trace** | Complete call stack showing where error happened |
| **Context** | Which part of code threw error |

---

## 💡 Smart Error Solutions

The detector also suggests fixes for common errors:

### **Example Output:**

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ NETWORK ERROR                        
╠═══════════════════════════════════════════════════════════╣
║  Error: SocketException: Connection refused
║  💡 Suggested Solution: 
║     Check network connection and backend server status
╚═══════════════════════════════════════════════════════════╝
```

---

## 🛠️ Advanced Usage

### **1. Wrap Widgets with Error Boundary**

Catch errors in specific parts of UI:

```dart
// Wrap any widget tree
ErrorBoundary(
  label: 'Product Grid',
  child: GridView.builder(...),
  errorWidget: Container(
    child: Text('Failed to load products'),
  ),
)
```

If an error occurs inside the grid, it shows the error widget instead of crashing.

---

### **2. Safe Async Operations**

Automatically catch errors in async code:

```dart
// Instead of this (might crash):
final products = await api.getProducts();

// Use this (safe, auto-catches errors):
final products = await ErrorDetector.safeAsync(
  operation: () => api.getProducts(),
  context: 'Fetching products from API',
  defaultValue: [], // Return empty list on error
  onError: (error, stack) {
    print('Handled error: $error');
  },
);
```

---

### **3. Safe Sync Operations**

Catch errors in synchronous code:

```dart
final result = ErrorDetector.safeSync(
  operation: () => riskyCalculation(),
  context: 'Calculating total price',
  defaultValue: 0.0,
);
```

---

### **4. Manual Error Reporting**

Report custom errors:

```dart
try {
  // Your code
} catch (e, stack) {
  ErrorDetector.reportError('Checkout process', e, stack);
}
```

Or for exceptions:

```dart
ErrorDetector.reportException('Loading user data', exception);
```

---

## 🎯 Common Error Examples

### **Example 1: Backend Server Not Running**

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ ASYNC ERROR DETECTED                 
╠═══════════════════════════════════════════════════════════╣
║  Error Type: SocketException
║  Message: Connection refused (OS Error: Connection refused)
╠───────────────────────────────────────────────────────────╢
║  💡 Suggested Solution: 
║     Check network connection and backend server status
╚═══════════════════════════════════════════════════════════╝
```

**Fix:** Start backend with `node server.js`

---

### **Example 2: Wrong API URL**

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ NETWORK ERROR                        
╠═══════════════════════════════════════════════════════════╣
║  Error Type: ClientException
║  Message: Failed host lookup: 192.168.1.999
╠───────────────────────────────────────────────────────────╢
║  💡 Suggested Solution: 
║     Check network connection and backend server status
╚═══════════════════════════════════════════════════════════╝
```

**Fix:** Update IP in `api_endpoints.dart`

---

### **Example 3: UI Overflow**

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ FLUTTER FRAMEWORK ERROR              
╠═══════════════════════════════════════════════════════════╣
║  Error Type: FlutterError
║  Message: A RenderFlex overflowed by 40 pixels on the right.
╠───────────────────────────────────────────────────────────╢
║  💡 Suggested Solution: 
║     Use SingleChildScrollView or constrain widget sizes
╚═══════════════════════════════════════════════════════════╝
```

**Fix:** Wrap in `SingleChildScrollView` or use `Expanded`

---

### **Example 4: Missing Asset**

```
╔═══════════════════════════════════════════════════════════╗
║                    ❌ ASSET LOADING ERROR                  
╠═══════════════════════════════════════════════════════════╣
║  Error Type: UnableToLoadAsset
║  Message: Does not exist: assets/icons/product.png
╠───────────────────────────────────────────────────────────╢
║  💡 Suggested Solution: 
║     Verify asset exists in pubspec.yaml and file path is correct
╚═══════════════════════════════════════════════════════════╝
```

**Fix:** Add asset to `pubspec.yaml`:
```yaml
assets:
  - assets/icons/product.png
```

---

## 📱 Test on Physical Device

### **Steps:**

1. **Run app on device:**
```bash
flutter run
```

2. **Trigger an error intentionally** (for testing):
```dart
// Tap a button that calls non-existent API
// Or divide by zero
final x = 1 ~/ 0; // Integer division by zero
```

3. **Check console output** - You'll see detailed error log!

---

## 🔧 Debugging Workflow

### **When Error Occurs:**

1. **Check Console**
   - Look for the formatted error box
   - Note the error type and message

2. **Read Stack Trace**
   - Shows exact file and line number
   - Follow the call stack to find root cause

3. **Check Suggested Solution**
   - System provides fix suggestions
   - Apply the recommended fix

4. **Reproduce & Verify**
   - Try to reproduce the error
   - Verify fix resolves it

---

## 📊 Error Categories

The detector categorizes errors for easier debugging:

| Category | Examples |
|----------|----------|
| **Flutter Framework** | Build errors, render issues, key errors |
| **Async** | Future/Stream failures, timeout errors |
| **Network** | Socket, connection, HTTP errors |
| **Null** | Null pointer, checked exceptions |
| **Type** | Cast errors, type mismatches |
| **Asset** | Image loading, file not found |
| **Permission** | Camera, storage, location denied |
| **Custom** | Your manually reported errors |

---

## 💾 Save Error Logs (Optional)

Want to save errors to file? Uncomment the file saving code in `_saveErrorToFile()`:

```dart
// In error_detector.dart, line ~75
Future<void> _saveErrorToFile(...) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/error_logs.txt');
  await file.writeAsString('''
[$timestamp] $type
Error: $error
Stack: ${stack?.toString()}
═══════════════════════════════\n
  ''', mode: FileMode.append);
}
```

Then add to `pubspec.yaml`:
```yaml
dependencies:
  path_provider: ^2.1.1
```

---

## 🎯 Benefits

✅ **No More Silent Failures** - Every error gets logged  
✅ **Faster Debugging** - See exact error location  
✅ **Physical Device Friendly** - No IDE needed to see errors  
✅ **Smart Suggestions** - Get fix recommendations  
✅ **Production Ready** - Can be used in release builds too  
✅ **Zero Performance Impact** - Runs only when errors occur  

---

## 🚨 Important Notes

### **Debug vs Release Mode:**

- **Debug Mode**: Shows detailed error info + extra logging
- **Release Mode**: Logs errors silently, no verbose output

### **Don't Remove!**

Keep `ErrorDetector.initialize()` in `main.dart` - it's your safety net!

### **Thread-Safe:**

Works with isolates, async/await, and multi-threaded code.

---

## ✅ Quick Reference

### **Enable Error Detection:**
Already done in `main.dart`! ✓

### **View Errors:**
Just run app and check console when error occurs

### **Wrap Risky Code:**
```dart
ErrorBoundary(
  label: 'My Widget',
  child: MyRiskyWidget(),
)
```

### **Safe API Calls:**
```dart
final data = await ErrorDetector.safeAsync(
  operation: () => fetchApi(),
  context: 'API Request',
);
```

---

## 🎉 You're All Set!

The error detector is now **always watching** and will catch any error that occurs on your device. When something goes wrong:

1. **Check your console** - Detailed error log will be there
2. **Read the suggestion** - Smart fix recommendation included
3. **Fix the issue** - Apply the suggested solution
4. **Test again** - Verify error is resolved

**Happy debugging with zero silent failures!** 🐛✨

---

*Generated on: April 3, 2026*  
*OmniCommerce POS - Global Error Detection System*
