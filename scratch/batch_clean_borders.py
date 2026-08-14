import os
import re

lib_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib"

# Targeted patterns to clean:
# 1. Single line: border: Border.all(...),
# 2. Single line: border: Border(top: ...),
# 3. side: BorderSide(color: ...),
# 4. Multi-line Border.all

def clean_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    orig = content

    # Remove border: Border.all(color: ...), / border: Border.all(...),
    content = re.sub(r'border:\s*Border\.all\([^)]+\),?\n?', '', content)
    content = re.sub(r'border:\s*Border\([^)]+\),?\n?', '', content)
    content = re.sub(r'side:\s*BorderSide\([^)]+\),?\n?', '', content)
    
    # Remove ternary border: active ? Border.all(...) : null,
    content = re.sub(r'border:\s*[^,\n]+\?\s*Border\.all\([^)]+\)\s*:\s*null,?\n?', '', content)

    if content != orig:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Cleaned {os.path.basename(filepath)}")

# Process lib
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            clean_file(os.path.join(root, file))

print("Batch clean complete!")
