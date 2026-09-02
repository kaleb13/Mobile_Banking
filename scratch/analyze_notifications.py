import sqlite3

con = sqlite3.connect('scratch/finance_live_analysis.db')
cur = con.cursor()

total = cur.execute("SELECT COUNT(*) FROM notifications").fetchone()[0]
unread = cur.execute("SELECT COUNT(*) FROM notifications WHERE isRead = 0").fetchone()[0]
print(f"Total notifications: {total}, Unread: {unread}")

rows = cur.execute("SELECT id, sender, body, date, isRead, reason, transactionId FROM notifications ORDER BY date DESC").fetchall()
print(f"Listing {len(rows)} notifications in DB:")
for i, r in enumerate(rows):
    print(f"[{i+1}] ID={r[0]} | Sender={r[1]} | Date={r[3]} | isRead={r[4]} | Reason={r[5]} | TxId={r[6]}")
    print(f"    Body: {repr(r[2])}")
    print("-" * 70)
