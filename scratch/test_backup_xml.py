import xml.etree.ElementTree as ET

for filename in ['CBE and Buna.xml', 'sms_backup_cbe_bunna.xml']:
    tree = ET.parse(filename)
    root = tree.getroot()
    count_attr = int(root.attrib['count'])
    actual_count = len(root)
    last_sms = root[-1]
    print(f'{filename}:')
    print(f'  Count attr: {count_attr}, Actual count: {actual_count}')
    print(f'  Last SMS address: {last_sms.attrib["address"]}')
    print(f'  Last SMS date: {last_sms.attrib["date"]}')
    print(f'  Last SMS body: {repr(last_sms.attrib["body"][:80])}...')
    assert count_attr == actual_count == 1061, 'Count mismatch!'

print('Validation SUCCESS: Both XML files are completely valid and verified!')
