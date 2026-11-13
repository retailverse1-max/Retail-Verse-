import os
import re

directory = 'lib/'

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
            
            # Replace backgroundColor: AppColors.success with backgroundColor: AppColors.secondary
            # ONLY inside SnackBar( ... )
            # A simple regex for this might be complex, so we can just replace backgroundColor: AppColors.success if the file has "SnackBar"
            if 'SnackBar' in content:
                new_content = re.sub(r'backgroundColor:\s*AppColors\.success', r'backgroundColor: AppColors.secondary', content)
                new_content = re.sub(r'backgroundColor:\s*AppColors\.error', r'backgroundColor: AppColors.secondary', new_content)
                new_content = re.sub(r'backgroundColor:\s*AppColors\.warning', r'backgroundColor: AppColors.secondary', new_content)
                new_content = re.sub(r'backgroundColor:\s*AppColors\.info', r'backgroundColor: AppColors.secondary', new_content)
                
                if new_content != content:
                    with open(filepath, 'w') as f:
                        f.write(new_content)
                    print(f"Fixed {filepath}")
