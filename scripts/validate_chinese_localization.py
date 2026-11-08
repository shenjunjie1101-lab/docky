#!/usr/bin/env python3
"""Check translation coverage, format arguments and executable catalog data."""
import collections
import json
import re
import subprocess
from pathlib import Path

catalog = json.loads(Path('Docky/Localizable.xcstrings').read_text())['strings']
format_token = re.compile(r'%%|%(?:\d+\$)?[-+0#]*\d*(?:\.\d+)?(?:ll|l|h|z|t|j|L)?[@diuoxXfFeEgGaAcCsSp]')
for key, entry in catalog.items():
    unit = entry.get('localizations', {}).get('zh-Hans', {}).get('stringUnit')
    assert unit and unit['state'] == 'translated', f'Missing Chinese translation: {key!r}'
    assert collections.Counter(format_token.findall(key)) == collections.Counter(format_token.findall(unit['value'])), f'Format arguments changed: {key!r}'

def executable_data(value):
    if isinstance(value, dict):
        return {k: executable_data(v) for k, v in value.items() if k not in ('title', 'description')}
    if isinstance(value, list):
        return [executable_data(v) for v in value]
    return value

for filename in ('actions.json', 'menus.json'):
    path = 'Docky/MenuCatalog/' + filename
    original = json.loads(subprocess.check_output(['git', 'show', '66596c41e77f89593aa807ca300efbac1e679164:' + path]))
    current = json.loads(Path(path).read_text())
    assert executable_data(original) == executable_data(current), f'Action IDs, scripts or menu paths changed: {path}'

for path in Path('Docky/zh-Hans.lproj').glob('*.strings'):
    entries = []
    for line in path.read_text().splitlines():
        key, value = line.rstrip(';').split(' = ', 1)
        entries.append((json.loads(key), json.loads(value)))
    assert len(dict(entries)) == len(entries), f'Duplicate string-table keys: {path}'
    assert entries, f'Empty string table: {path}'

print(f'Chinese coverage: {len(catalog)}/{len(catalog)}; format arguments, native string tables, action IDs, scripts and menu paths verified')
