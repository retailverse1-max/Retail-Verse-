import os
import re

directory = 'lib/'

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            # First, strip existing duration to avoid duplicates
            content = re.sub(r'duration:\s*const Duration\([^)]+\),\s*', '', content)
            content = re.sub(r'duration:\s*Duration\([^)]+\),\s*', '', content)
            
            # Now, add our standard duration right after SnackBar(
            # This regex replaces 'SnackBar(' with 'SnackBar(duration: const Duration(seconds: 2),'
            new_content = re.sub(r'\bSnackBar\(', r'SnackBar(duration: const Duration(seconds: 2),', content)
            
            if new_content != content:
                with open(filepath, 'w') as f:
                    f.write(new_content)
                print(f"Fixed {filepath}")
