import os
import re

lib_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib"

hardcoded_hex_regex = re.compile(r'Color\s*\(\s*0x[0-9a-fA-F]+\s*\)')
material_color_regex = re.compile(r'Colors\.(white|black|grey|blue|red|green|amber|teal|orange|purple|deepPurple|indigo|cyan|yellow|pink|lightBlue|lightGreen|lime)\b')
appbar_regex = re.compile(r'\bAppBar\s*\(')
textfield_regex = re.compile(r'\b(TextField|TextFormField)\s*\(')
elevated_button_regex = re.compile(r'\b(ElevatedButton|OutlinedButton)\s*\(')
alert_dialog_regex = re.compile(r'\bAlertDialog\s*\(')

findings = {
    'hardcoded_hex': [],
    'material_colors': [],
    'appbars': [],
    'textfields': [],
    'buttons': [],
    'alert_dialogs': [],
}

exempt_files = [
    'app_theme.dart',
    'app_colors.dart',
    'app_typography.dart',
    'app_button.dart',
    'app_header.dart',
    'app_text_field.dart',
    'app_empty_state.dart',
    'app_list_tile.dart',
    'app_bottom_sheet.dart',
    'app_confirm_dialog.dart',
]

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
            
            # Check hardcoded hex
            if f not in ['app_theme.dart', 'app_colors.dart']:
                matches = hardcoded_hex_regex.findall(line)
                if matches:
                    findings['hardcoded_hex'].append((relpath, idx, line.strip(), matches))
            
            # Check material colors
            if f not in exempt_files:
                matches = material_color_regex.findall(line)
                if matches:
                    findings['material_colors'].append((relpath, idx, line.strip(), matches))
                    
            # Check AppBars
            if f not in exempt_files:
                if appbar_regex.search(line):
                    findings['appbars'].append((relpath, idx, line.strip()))
                    
            # Check raw TextFields
            if f not in exempt_files:
                if textfield_regex.search(line):
                    findings['textfields'].append((relpath, idx, line.strip()))
                    
            # Check raw Buttons
            if f not in exempt_files:
                if elevated_button_regex.search(line):
                    findings['buttons'].append((relpath, idx, line.strip()))
                    
            # Check AlertDialogs
            if f not in exempt_files:
                if alert_dialog_regex.search(line):
                    findings['alert_dialogs'].append((relpath, idx, line.strip()))

print(f"=== AUDIT RESULTS ===")
print(f"1. Hardcoded Hex Colors: {len(findings['hardcoded_hex'])}")
for path, line_no, content, matches in findings['hardcoded_hex'][:25]:
    print(f"  {path}:{line_no} -> {matches} | {content[:80]}")

print(f"\n2. Raw AppBars (should use AppHeader): {len(findings['appbars'])}")
for path, line_no, content in findings['appbars']:
    print(f"  {path}:{line_no} -> {content[:80]}")

print(f"\n3. Raw TextFields (should use AppTextField): {len(findings['textfields'])}")
for path, line_no, content in findings['textfields'][:25]:
    print(f"  {path}:{line_no} -> {content[:80]}")

print(f"\n4. Raw Buttons (should use AppButton): {len(findings['buttons'])}")
for path, line_no, content in findings['buttons'][:25]:
    print(f"  {path}:{line_no} -> {content[:80]}")

print(f"\n5. Raw AlertDialogs (should use AppConfirmDialog): {len(findings['alert_dialogs'])}")
for path, line_no, content in findings['alert_dialogs']:
    print(f"  {path}:{line_no} -> {content[:80]}")

print(f"\n6. Material Colors (Colors.xxx): {len(findings['material_colors'])}")
# group by file
files_with_mat_colors = {}
for path, line_no, content, matches in findings['material_colors']:
    files_with_mat_colors[path] = files_with_mat_colors.get(path, 0) + len(matches)
for p, c in sorted(files_with_mat_colors.items(), key=lambda x: x[1], reverse=True)[:15]:
    print(f"  {p}: {c} occurrences")
