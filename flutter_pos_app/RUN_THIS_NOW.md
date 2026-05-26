# Quick Start - Test Login Fix NOW

## ⚡ 3-Minute Setup

### Step 1: Verify Backend is Running
```bash
cd backend
npm start
# or
node server.js
```

You should see: `Server running on port 5000`

### Step 2: Check Your IP Address

**On Mac:**
```bash
ipconfig getifaddr en0
```

**On Windows:**
```bash
ipconfig
```

If your IP is NOT `192.168.1.7`, update it:

**File:** `lib/core/constants/api_endpoints.dart`
```dart
static const String _lanBaseUrl = 'http://YOUR_IP:5000/api';
```

### Step 3: Connect Both Devices to SAME Wi-Fi

- ✅ Laptop connected to Wi-Fi
- ✅ Android phone connected to SAME Wi-Fi
- ❌ Not on cellular data
- ❌ Not on different networks

### Step 4: Run Flutter App

```bash
cd flutter_pos_app
flutter run
```

### Step 5: Test Login

1. Open app on your Android device
2. Enter email and password
3. Tap "Sign In"
4. Watch console logs for debugging

## 🐛 If You Get Errors

### "Server unreachable"
```
✅ Backend is running?
✅ Same Wi-Fi network?
✅ IP address correct in api_endpoints.dart?
✅ Firewall disabled or allowing port 5000?
```

**Quick Test:** Open browser on phone and go to:
`http://192.168.1.7:5000/api`

If it loads → Backend is reachable  
If it doesn't → Check steps above

### "Connection timed out"
- Backend might be slow
- Network issues
- Try again

### White Card Still Showing?
**Hot Restart Required:**
- Press `Shift + R` in terminal
- OR tap restart button in Flutter dev tools

## 📱 Expected Behavior

**When Keyboard Opens:**
- ✅ Form scrolls up smoothly
- ✅ No white card overlay
- ✅ All fields visible
- ✅ Can type comfortably

**When Login Succeeds:**
- ✅ Shows loading spinner
- ✅ Navigates to dashboard
- ✅ No errors

**When Login Fails:**
- ✅ Shows clear error message
- ✅ Button becomes enabled again
- ✅ Can retry

## 🔍 Debug Console Output

**Success:**
```
🔵 AuthService [Login]
  URL: http://192.168.1.7:5000/api/auth/login
  Status Code: 200
✅ AuthService: Login successful
```

**Failure:**
```
❌ AuthService: SocketException - Server unreachable
  This usually means:
    - Backend server is not running
    - Phone and laptop are not on same Wi-Fi
    - IP address is incorrect
    - Firewall is blocking
```

## 🎯 That's It!

Your login should work now. If still having issues, read the detailed error message in console - it will tell you exactly what's wrong.

Good luck! 🚀
