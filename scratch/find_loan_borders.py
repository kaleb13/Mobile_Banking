filepath = r"c:\Users\kaleb\Documents\Mobile_Banking\lib\screens\loans\loan_management_screen.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines, 1):
    if 'border' in line.lower():
        print(f"Line {i:4d}: {line.strip()}")
