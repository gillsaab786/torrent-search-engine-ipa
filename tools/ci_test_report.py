"""Turns `flutter test --machine` output into GitHub annotations."""
import json, sys

def esc(s):
    return s.replace('%', '%25').replace('\r', '').replace('\n', '%0A')

names, fails, events = {}, [], 0
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        e = json.loads(line)
    except ValueError:
        continue
    events += 1
    t = e.get('type')
    if t == 'testStart':
        names[e['test']['id']] = e['test'].get('name', '?')
    elif t == 'error':
        fails.append((names.get(e.get('testID'), '?'), e.get('error', ''), e.get('stackTrace', '')))
    elif t == 'print' and 'Error' in e.get('message', ''):
        fails.append(('output', e.get('message', ''), ''))

print(f'::notice::Parsed {events} test events, {len(fails)} failures')
for name, err, stack in fails[:8]:
    print(f'::error::{esc(name)} — {esc(err[:500])} @ {esc(stack[:300])}')
