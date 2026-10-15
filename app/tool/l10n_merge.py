#!/usr/bin/env python3
"""Merge l10n_src/<area>.<lang>.arb fragments into lib/l10n/app_<lang>.arb.

Each screen/area owns its fragments, so parallel edits never touch one file.
Run before `flutter gen-l10n`. Keys must be unique across areas, and every
Thai key needs an English twin (and the reverse).
"""
import glob, json, os, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
langs = {}
for path in sorted(glob.glob(os.path.join(root, 'l10n_src', '*.arb'))):
    area, lang, _ = os.path.basename(path).rsplit('.', 2)
    with open(path, encoding='utf8') as f:
        data = json.load(f)
    merged = langs.setdefault(lang, {})
    for k, v in data.items():
        if k in merged:
            sys.exit(f'duplicate key {k} ({area}.{lang})')
        merged[k] = v

th, en = langs.get('th', {}), langs.get('en', {})
plain = lambda d: {k for k in d if not k.startswith('@')}
if plain(th) != plain(en):
    sys.exit('th/en keys differ: ' + ', '.join(sorted(plain(th) ^ plain(en))))
for lang, d in (('th', th), ('en', en)):
    out = {'@@locale': lang, **d}
    with open(os.path.join(root, 'lib', 'l10n', f'app_{lang}.arb'), 'w', encoding='utf8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write('\n')
print(f'merged {len(plain(th))} keys')
