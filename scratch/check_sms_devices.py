import subprocess

def check_device_sms(device_id):
    print(f"=== Checking SMS for {device_id} ===")
    try:
        p = subprocess.Popen(['adb', '-s', device_id, 'shell', 'content', 'query', '--uri', 'content://sms', '--projection', '_id:address:body:date:read', '--sort', 'date DESC'], stdout=subprocess.PIPE)
        out, _ = p.communicate()
        raw = out.decode('utf-8', errors='ignore')
        rows = raw.split('Row: ')
        print(f"Total SMS count: {len(rows)-1}")
        
        # Check unread (read=0)
        unread_rows = []
        banking_senders = ['cbe', 'telebirr', 'ahadu', 'boa', 'dashen', 'awash', 'cbebirr', '127']
        banking_rows = []
        
        for r in rows[1:]:
            is_unread = 'read=0' in r
            is_banking = any(b in r.lower() for b in banking_senders)
            if is_unread:
                unread_rows.append(r.strip())
            if is_banking:
                banking_rows.append(r.strip())
                
        print(f"Total unread SMS (read=0): {len(unread_rows)}")
        print(f"Total banking SMS: {len(banking_rows)}")
        
        print("\n--- Recent Unread Banking SMS (up to 10) ---")
        unread_banking = [r for r in unread_rows if any(b in r.lower() for b in banking_senders)]
        print(f"Total unread banking SMS: {len(unread_banking)}")
        for ub in unread_banking[:10]:
            print(ub)
            print("-" * 40)
            
    except Exception as e:
        print(f"Error on {device_id}: {e}")

check_device_sms('192.168.1.5:46537')
check_device_sms('adb-RF8T904ZDKR-KZ60da._adb-tls-connect._tcp')
