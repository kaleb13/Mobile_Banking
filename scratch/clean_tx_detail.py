import re

filepath = r"c:\Users\kaleb\Documents\Mobile_Banking\lib\screens\dashboard\transaction_detail_screen.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
skip = 0

for i, line in enumerate(lines):
    # Remove side: BorderSide(...)
    if 'side: BorderSide(' in line:
        continue
    # Remove border: Border.all(
    if 'border: Border.all(' in line:
        # Check if single line
        if ')' in line and not line.count('(') > line.count(')'):
            continue
        else:
            # Multi-line, skip until matching closing paren
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
    
    # Replace enabledBorder: UnderlineInputBorder(borderSide: ...)
    line = re.sub(r'enabledBorder:\s*UnderlineInputBorder\([^)]+\)', 'enabledBorder: const UnderlineInputBorder(borderSide: BorderSide.none)', line)
    line = re.sub(r'focusedBorder:\s*const\s*UnderlineInputBorder\([^)]+\)', 'focusedBorder: const UnderlineInputBorder(borderSide: BorderSide.none)', line)
    line = re.sub(r'focusedBorder:\s*UnderlineInputBorder\([^)]+\)', 'focusedBorder: const UnderlineInputBorder(borderSide: BorderSide.none)', line)
    line = re.sub(r'border:\s*OutlineInputBorder\(borderRadius:\s*BorderRadius\.circular\(12\)\)', 'border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)', line)

    out.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(out)

print("transaction_detail_screen.dart cleaned!")
