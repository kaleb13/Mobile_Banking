import sys
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding='utf-8')

with open('CBE and Buna.xml', 'r', encoding='utf-8') as f:
    content = f.read()

# Update count from 1060 to 1061
new_content = content.replace('count="1060"', 'count="1061"', 1)

new_sms_line = '  <sms protocol="0" address="Bunna Bank" date="1788699328000" type="1" subject="null" body="Dear Customer&#10;A Deposit of 1.00 ETB has been made to your account 426***611 BY TELEBIRR RECEIVABLE ACCOUNT TELEINCOME on 06-09-2026 15:55:28, your current balance is 219.47 ETB. Thank you.&#10;Bunna Bank" toa="null" sc_toa="null" service_center="+251971200122" read="1" status="-1" locked="0" date_sent="1788699328000" sub_id="1" readable_date="6 Sept 2026 3:55:28 pm" contact_name="(Unknown)" />\n'

closing = '</smses>'
idx = new_content.rfind(closing)
if idx != -1:
    final_content = new_content[:idx] + new_sms_line + new_content[idx:]
    with open('sms_backup_cbe_bunna.xml', 'w', encoding='utf-8') as out_f:
        out_f.write(final_content)
    with open('CBE and Buna.xml', 'w', encoding='utf-8') as out_f2:
        out_f2.write(final_content)
    print("SUCCESS: Generated sms_backup_cbe_bunna.xml and updated CBE and Buna.xml")
else:
    print("ERROR: closing tag not found")
