import subprocess
import re

p = subprocess.Popen(['adb', '-s', '192.168.1.5:46537', 'shell', 'content', 'query', '--uri', 'content://sms', '--projection', '_id:address:body:date', '--sort', 'date DESC'], stdout=subprocess.PIPE)
out, _ = p.communicate()
raw = out.decode('utf-8', errors='ignore')

# Regex to find each row: Row: <num> _id=<id>, address=<addr>, body=<body>, date=<date>
pattern = re.compile(r'Row:\s*\d+\s+_id=(\d+),\s*address=([^,]*),\s*body=(.*?),\s*date=(\d+)', re.DOTALL)
matches = list(pattern.finditer(raw))
print(f"Total SMS parsed by regex: {len(matches)}")

bank_keywords = ['cbe', 'telebirr', 'ahadu', 'boa', 'dashen', 'awash', '127', 'cbebirr']

banking_messages = []
for m in matches:
    _id, addr, body, dt = m.groups()
    addr_clean = addr.strip().lower()
    if any(bk in addr_clean for bk in bank_keywords):
        banking_messages.append({
            'id': _id,
            'address': addr.strip(),
            'body': body.strip(),
            'date': dt
        })

print(f"Total banking messages found: {len(banking_messages)}")
unique_bodies = {}
for m in banking_messages:
    b = m['body']
    if b not in unique_bodies:
        unique_bodies[b] = m

print(f"Unique banking message bodies: {len(unique_bodies)}")
