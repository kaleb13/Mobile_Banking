import os

settings_dir = r"c:\Users\kaleb\Documents\Mobile_Banking\lib\screens\settings"

for file in os.listdir(settings_dir):
    if file.endswith('.dart'):
        filepath = os.path.join(settings_dir, file)
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        for i, line in enumerate(lines, 1):
            if 'border:' in line.lower() or 'borderside' in line.lower():
                print(f"{file} Line {i:4d}: {line.strip()}")
