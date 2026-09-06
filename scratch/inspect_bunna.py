import xml.etree.ElementTree as ET

tree = ET.parse('CBE and Buna.xml')
root = tree.getroot()
bunna_sms = [el for el in root.findall('sms') if el.get('address') == 'Bunna Bank']
print(f"Total Bunna SMS count: {len(bunna_sms)}")

with open('scratch/bunna_sms_samples.txt', 'w', encoding='utf-8') as f:
    for i, el in enumerate(bunna_sms):
        date = el.get('date')
        readable_date = el.get('readable_date')
        body = el.get('body')
        f.write(f"=== SMS #{i+1} (Date: {date} | {readable_date}) ===\n")
        f.write(f"{body}\n\n")

print("Saved all Bunna SMS messages to scratch/bunna_sms_samples.txt")
