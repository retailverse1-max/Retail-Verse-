# 🔄 Database Reset Guide for Categories

## ⚠️ Problem
The categories table was missing from the database schema. This has been fixed, but your existing database doesn't have the table yet.

## ✅ Solution Options

### **Option 1: Clear App Data (Recommended - Easiest)**

#### **On Android Emulator/Device:**
```bash
# Method 1: Using ADB
adb uninstall com.example.omnicommercePos

# Method 2: From device settings
# Settings → Apps → OmniCommerce POS → Storage → Clear Data
```

#### **On iOS Simulator:**
```bash
# Delete and reinstall the app
flutter clean
flutter run
```

#### **On Desktop/Web:**
Just restart the app - it will use the new schema automatically.

---

### **Option 2: Programmatic Database Reset**

Add this temporary button to your app to reset the database:

```dart
// In your main.dart or a debug screen
ElevatedButton(
  onPressed: () async {
    await AppDatabase.deleteDB(); // Add this method
    print('✅ Database cleared!');
    // Restart app
  },
  child: Text('Reset Database'),
)
```

---

### **Option 3: Manual File Deletion**

#### **Android:**
```bash
adb shell
cd /data/data/com.example.omnicommercePos/databases/
rm pos_app.db
exit
```

#### **iOS Simulator:**
Navigate to:
```
~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/documents/
```
Delete `pos_app.db`

---

## 🎯 After Reset

Once you've cleared the database:

1. **Run the app again:**
   ```bash
   flutter run
   ```

2. **Navigate to Inventory → Categories**

3. **You should see:**
   - 6 sample categories auto-loaded
   - No errors in console

4. **Test adding a category:**
   - Tap "Add Category"
   - Enter name: "Electronics"
   - Tap "Add Category"
   - Pull down to refresh OR restart app
   - ✅ **Category should STILL be there!**

---

## 🔍 How to Verify It's Working

### **Check Console Logs:**
After reset, you should see:
```
🔄 Upgrading database from version 1 to 2
✅ Categories table added successfully
✅ Loaded 6 categories from database
```

### **Check Sample Categories:**
You should see these 6 categories:
1. Central Components
2. Peripherals
3. Connectors
4. Body
5. Sensors
6. Tools

---

## 🐛 Troubleshooting

### **Still Not Working?**

1. **Check if database file exists:**
   ```bash
   # Android
   adb shell ls /data/data/com.example.omnicommercePos/databases/
   
   # Should show: pos_app.db
   ```

2. **Force close and clear cache:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check console for errors:**
   Look for lines starting with ❌ that mention "categories"

4. **Verify database version:**
   The app should log:
   ```
   🔄 Upgrading database from version 1 to 2
   ```

---

## 📝 What Was Fixed

### **Before:**
- ❌ No categories table in database
- ❌ Changes lost on refresh
- ❌ Only mock data worked

### **After:**
- ✅ Categories table created
- ✅ Database version incremented to v2
- ✅ Migration handler added
- ✅ Auto-seeding works
- ✅ Persistence works!

---

## 🎊 Success Checklist

After reset, verify:
- [ ] App runs without errors
- [ ] 6 sample categories appear
- [ ] Can add new category
- [ ] Category persists after refresh
- [ ] Category persists after app restart
- [ ] Can delete category
- [ ] Deleted category stays deleted

---

## 🚀 Quick Fix Command

**Fastest way (Android):**
```bash
adb uninstall com.example.omnicommercePos && flutter run
```

This will:
1. Uninstall the app (clearing all data)
2. Reinstall with new database schema
3. Auto-seed sample categories

---

**Status:** ✅ Database Schema Fixed  
**Action Required:** Clear app data once  
**Result:** Categories will persist forever! 🎉
