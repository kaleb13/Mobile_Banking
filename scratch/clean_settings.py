import os
import re

settings_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib\screens\settings"

def clean_settings_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    out = []
    skip = 0
    for i, line in enumerate(lines):
        if 'border: Border.all(' in line:
            if ')' in line and not line.count('(') > line.count(')'):
                continue
            else:
                skip_count = line.count('(') - line.count(')')
                for j in range(i + 1, len(lines)):
                    skip_count += lines[j].count('(') - lines[j].count(')')
                    if skip_count <= 0:
                        skip = j - i
                        break
                continue
        if skip > 0:
            skip -= 1
            continue

        # Replace borderSide strokes
        line = re.sub(r'borderSide:\s*BorderSide\([^)]+\)', 'borderSide: BorderSide.none', line)
        line = re.sub(r'borderSide:\s*const\s*BorderSide\([^)]+\)', 'borderSide: BorderSide.none', line)
        out.append(line)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(out)
    print(f"Cleaned {os.path.basename(filepath)}")

for file in os.listdir(settings_dir):
    if file.endswith('.dart'):
        clean_settings_file(os.path.join(settings_dir, file))
