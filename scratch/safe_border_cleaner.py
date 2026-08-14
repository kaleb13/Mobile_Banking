import os
import re

lib_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib"

# Skip files where we already hand-tuned them or custom logic
skip_files = {'app_typography.dart'}

def remove_borders_from_code(code: str) -> str:
    # 1. Single-line border: Border.all(...),
    # Handles border: Border.all(color: ...),
    # border: Border.all(color: ..., width: ...),
    code = re.sub(r'border:\s*Border\.all\([^()]*(?:\([^()]*\)[^()]*)*\),?\n?', '', code)
    
    # 2. Single-line border: Border(top: ...),
    code = re.sub(r'border:\s*Border\([^()]*(?:\([^()]*\)[^()]*)*\),?\n?', '', code)

    # 3. side: BorderSide(...) inside shapes or buttons
    code = re.sub(r'side:\s*BorderSide\([^()]*(?:\([^()]*\)[^()]*)*\),?\n?', '', code)
    code = re.sub(r'side:\s*const\s*BorderSide\([^()]*(?:\([^()]*\)[^()]*)*\),?\n?', '', code)

    # 4. Ternary border: isSelected ? Border.all(...) : null,
    # or border: isSelected ? Border.all(...) : Border.all(...)
    code = re.sub(r'border:\s*[^;\n,]+\?\s*Border\.all\([^()]*(?:\([^()]*\)[^()]*)*\)\s*:\s*(?:null|Border\.all\([^()]*(?:\([^()]*\)[^()]*)*\)),?\n?', '', code)

    # 5. Multi-line Border.all inside BoxDecoration
    lines = code.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Detect start of multi-line border:
        if re.search(r'^\s*border:\s*(?:(?:Border\.all|Border)\(|\w+\s*\?\s*Border\.all\()', line):
            # Track parentheses until balanced
            open_count = line.count('(') - line.count(')')
            while open_count > 0 and i + 1 < len(lines):
                i += 1
                open_count += lines[i].count('(') - lines[i].count(')')
            i += 1
            continue
        new_lines.append(line)
        i += 1

    return '\n'.join(new_lines)

count = 0
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart') and file not in skip_files:
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            new_content = remove_borders_from_code(content)
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Cleaned {file}")
                count += 1

print(f"Done! Cleaned {count} files.")
