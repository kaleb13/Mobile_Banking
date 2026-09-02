import sqlite3

con = sqlite3.connect('scratch/finance_device.db')
cur = con.cursor()

print("=== Search for 4669 ===")
query1 = """
SELECT id, name, amount, type, date, bankReference, simSlot, rawMessage 
FROM transactions 
WHERE amount = 4669 OR amount LIKE '%4669%' OR rawMessage LIKE '%4669%' OR rawMessage LIKE '%4,669%'
ORDER BY date DESC
"""
rows = cur.execute(query1).fetchall()
print(f"Found {len(rows)} matching 4669")
for r in rows:
    print('---')
    print('ID:', r[0])
    print('Name:', r[1])
    print('Amount:', r[2])
    print('Type:', r[3])
    print('Date:', r[4])
    print('Ref:', r[5])
    print('Slot:', r[6])
    print('Raw:', repr(r[7]))
