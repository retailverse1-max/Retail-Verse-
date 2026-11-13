import re

errors = [
    ("lib/features/auth/presentation/screens/onboarding_screen.dart", 123, "TweenAnimationBuilder<double>("),
    ("lib/features/pos/presentation/screens/pos_billing_screen.dart", 790, "AnimatedContainer("),
    ("lib/features/pos/presentation/screens/pos_billing_screen.dart", 853, "AnimatedContainer("),
    ("lib/features/pos/presentation/screens/pos_screen.dart", 225, "AnimatedOpacity("),
    ("lib/features/pos/presentation/screens/pos_screen.dart", 461, "AnimatedContainer("),
    ("lib/features/pos/presentation/screens/pos_screen.dart", 513, "AnimatedContainer("),
    ("lib/features/subscription/presentation/screens/subscription_plans_screen.dart", 144, "AnimatedContainer("),
    ("lib/features/super_admin/presentation/screens/sa_settings_screen.dart", 438, "AnimatedScale("),
    ("lib/features/super_admin/presentation/screens/sa_subscriptions_screen.dart", 482, "AnimatedContainer("),
    ("lib/features/super_admin/presentation/screens/sa_subscriptions_screen.dart", 535, "AnimatedDefaultTextStyle("),
    ("lib/features/super_admin/presentation/screens/sa_subscriptions_screen.dart", 502, "AnimatedContainer("),
    ("lib/features/super_admin/presentation/screens/sa_subscriptions_screen.dart", 445, "AnimatedContainer("),
]

for filepath, line_num, widget_name in errors:
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        
        idx = line_num - 1
        # Insert duration after the widget name
        if widget_name in lines[idx]:
            lines[idx] = lines[idx].replace(widget_name, f"{widget_name} duration: const Duration(milliseconds: 300), ")
            with open(filepath, 'w') as f:
                f.writelines(lines)
            print(f"Fixed {filepath}:{line_num}")
    except Exception as e:
        print(f"Failed {filepath}:{line_num} - {e}")

# Fix duplicates
def fix_dup(filepath, line_num):
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
        idx = line_num - 1
        # find the second duration: const Duration(...) and remove it
        # Actually it's easier to just remove the last one or manually replace
        line = lines[idx]
        parts = line.split("duration:")
        if len(parts) > 2:
            # Reconstruct by dropping the last part
            # It's at the end: , duration: const Duration(seconds: 4))
            line = re.sub(r',\s*duration:\s*const Duration\([^)]+\)', '', line)
            lines[idx] = line
            with open(filepath, 'w') as f:
                f.writelines(lines)
            print(f"Fixed duplicate in {filepath}:{line_num}")
    except Exception as e:
        pass

fix_dup("lib/features/inventory/presentation/screens/add_product_screen.dart", 538)
fix_dup("lib/features/subscription/presentation/screens/subscription_plans_screen.dart", 42)

