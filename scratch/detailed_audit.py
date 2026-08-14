import os
import re

lib_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib"

findings = {
    'alert_dialogs': [],
    'raw_buttons': [],
    'raw_textfields': [],
    'legacy_files': [],
    'light_mode_contrast_risks': [],
}

for root, _, files in os.walk(lib_dir):
    for f in files:
        if not f.endswith('.dart'):
            continue
        filepath = os.path.join(root, f)
        relpath = os.path.relpath(filepath, lib_dir)
        
        # Skip theme & standard widget definition files
        if relpath.startswith('theme') or f in [
            'app_button.dart', 'app_header.dart', 'app_text_field.dart',
            'app_bottom_sheet.dart', 'app_empty_state.dart', 'app_list_tile.dart',
            'app_confirm_dialog.dart', 'widgets.dart'
        ]:
            continue
            
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as fp:
            content = fp.read()
            lines = content.splitlines()

        # Check raw AlertDialog
        for idx, line in enumerate(lines, 1):
            if 'AlertDialog(' in line:
                findings['alert_dialogs'].append(f"{relpath}:{idx} -> {line.strip()[:70]}")
                
        # Check raw Buttons
        for idx, line in enumerate(lines, 1):
            if 'ElevatedButton(' in line or 'OutlinedButton(' in line:
                findings['raw_buttons'].append(f"{relpath}:{idx} -> {line.strip()[:70]}")

        # Check raw TextFields
        for idx, line in enumerate(lines, 1):
            if re.search(r'\b(TextField|TextFormField)\s*\(', line):
                findings['raw_textfields'].append(f"{relpath}:{idx} -> {line.strip()[:70]}")
                
        # Check hardcoded Colors.white / Colors.black in UI widgets that might fail light mode
        for idx, line in enumerate(lines, 1):
            if re.search(r'color:\s*Colors\.(white|black)\b', line) and 'context.theme' not in line:
                # check if it's not brandGreen or on emerald
                findings['light_mode_contrast_risks'].append(f"{relpath}:{idx} -> {line.strip()[:70]}")

print(f"=== DETAILED REPORT ===")
print(f"\n1. Raw AlertDialogs ({len(findings['alert_dialogs'])}):")
for item in findings['alert_dialogs']:
    print("  ", item)

print(f"\n2. Raw Buttons ({len(findings['raw_buttons'])}):")
for item in findings['raw_buttons']:
    print("  ", item)

print(f"\n3. Raw TextFields ({len(findings['raw_textfields'])}):")
for item in findings['raw_textfields']:
    print("  ", item)

print(f"\n4. Potential Light Mode Contrast Risks (Colors.white/black without theme adaptation) ({len(findings['light_mode_contrast_risks'])}):")
for item in findings['light_mode_contrast_risks'][:20]:
    print("  ", item)
