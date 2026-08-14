import os
import re

lib_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib"

border_patterns = [
    re.compile(r'Border\.all\s*\('),
    re.compile(r'Border\s*\('),
    re.compile(r'BorderSide\s*\('),
    re.compile(r'borderSide:\s*'),
    re.compile(r'OutlineInputBorder\s*\('),
    re.compile(r'UnderlineInputBorder\s*\('),
]

findings = {}

for root, _, files in os.walk(lib_dir):
    for f in files:
        if not f.endswith('.dart'):
            continue
        filepath = os.path.join(root, f)
        relpath = os.path.relpath(filepath, lib_dir)
        
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as fp:
            lines = fp.readlines()
            
        for idx, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith('//') or stripped.startswith('*'):
                continue
            
            for pat in border_patterns:
                if pat.search(line):
                    if relpath not in findings:
                        findings[relpath] = []
                    findings[relpath].append((idx, stripped))
                    break

print(f"=== ALL BORDER / STROKE OCCURRENCES IN CODEBASE ===")
total_count = sum(len(v) for v in findings.values())
print(f"Total occurrences: {total_count} in {len(findings)} files\n")

# Prioritize widgets
for path, items in sorted(findings.items(), key=lambda x: (not x[0].startswith('widgets'), x[0])):
    print(f"--- {path} ({len(items)} borders) ---")
    for line_no, content in items:
        print(f"  Line {line_no:4d}: {content[:90]}")
    print()
