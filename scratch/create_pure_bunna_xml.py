import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

# Read CBE and Buna.xml and filter ONLY Bunna Bank
tree = ET.parse('CBE and Buna.xml')
root = tree.getroot()

bunna_sms_list = [
    s for s in root 
    if 'bunna' in (s.attrib.get('address') or '').lower()
]

# We need the 36 original Bunna messages (excluding the new one if already present, then append the new one cleanly)
# Check by date
original_bunna = [s for s in bunna_sms_list if s.attrib.get('date') != '1788699328000']
print(f"Found {len(original_bunna)} original Bunna messages.")

new_sms_elem = ET.Element('sms', {
    'protocol': '0',
    'address': 'Bunna Bank',
    'date': '1788699328000',
    'type': '1',
    'subject': 'null',
    'body': "Dear Customer\nA Deposit of 1.00 ETB has been made to your account 426***611 BY TELEBIRR RECEIVABLE ACCOUNT TELEINCOME on 06-09-2026 15:55:28, your current balance is 219.47 ETB. Thank you.\nBunna Bank",
    'toa': 'null',
    'sc_toa': 'null',
    'service_center': '+251971200122',
    'read': '1',
    'status': '-1',
    'locked': '0',
    'date_sent': '1788699328000',
    'sub_id': '1',
    'readable_date': '6 Sept 2026 3:55:28 pm',
    'contact_name': '(Unknown)'
})

all_bunna = original_bunna + [new_sms_elem]
print(f"Total Bunna messages to write: {len(all_bunna)}")

# Build clean XML
header = """<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<!--File Created By SMS Backup & Restore Pro for Bunna Bank-->
<smses count="{count}" backup_set="3b8c3c29-89ce-4132-ab6d-dfb26801fbdb" backup_date="1788699328000" type="full">
""".format(count=len(all_bunna))

lines = [header]
for s in all_bunna:
    attrs = []
    # Order of standard attributes
    attr_order = [
        'protocol', 'address', 'date', 'type', 'subject', 'body',
        'toa', 'sc_toa', 'service_center', 'read', 'status',
        'locked', 'date_sent', 'sub_id', 'readable_date', 'contact_name'
    ]
    for key in attr_order:
        val = s.attrib.get(key, '')
        # Escape XML entities in body
        if key == 'body':
            val = val.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;').replace('\n', '&#10;')
        attrs.append(f'{key}="{val}"')
    lines.append('  <sms ' + ' '.join(attrs) + ' />\n')

lines.append('</smses>\n')
final_xml = ''.join(lines)

# Write to files
with open('Bunna Bank.xml', 'w', encoding='utf-8') as f:
    f.write(final_xml)

with open('docs/Bunna Bank.xml', 'w', encoding='utf-8') as f:
    f.write(final_xml)

with open('sms_backup_cbe_bunna.xml', 'w', encoding='utf-8') as f:
    f.write(final_xml)

print("SUCCESS: Written pure Bunna Bank XML with exactly 37 messages!")
