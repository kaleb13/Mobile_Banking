import os
import re

widgets_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib\widgets"

border_patterns = [
    re.compile(r'Border\.all\s*\('),
    re.compile(r'Border\s*\('),
    re.compile(r'BorderSide\s*\('),
    re.compile(r'borderSide:\s*'),
    re.compile(r'OutlineInputBorder\s*\('),
    re.compile(r'UnderlineInputBorder\s*\('),
]

for root, _, files in os.walk(widgets_dir):
    for f in files:
        if not f.endswith('.dart'):
            continue
        filepath = os.path.join(root, f)
        relpath = os.path.relpath(filepath, widgets_dir)
        
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as fp:
            lines = fp.readlines()
            
        matches = []
        for idx, line in enumerate(lines, 1):
            for pat in border_patterns:
                if pat.search(line):
                    matches.append((idx, line.strip()))
                    break
                    
        if matches:
            print(f"=== {f} ({len(matches)} borders) ===")
            for line_no, content in matches:
                print(f"  Line {line_no:3d}: {content}")
            print()
