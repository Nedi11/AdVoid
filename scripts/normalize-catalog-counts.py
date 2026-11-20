#!/usr/bin/env python3
"""Use self-contained count labels so preformatted numbers need no plural agreement.

This deliberately updates only the count entries listed in localization-count-labels.json.
Labels and values remain one translated string, allowing each language to reorder them.
"""
import concurrent.futures
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('translate_catalog', ROOT / 'scripts/translate-catalog.py')
translator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(translator)
labels = json.loads((ROOT / 'scripts/localization-count-labels.json').read_text())
locales = [r['bundle'] for r in json.loads((ROOT / 'scripts/localization-locales.json').read_text())]

def prepare(locale):
    if locale == 'en' or locale.startswith('en-'): return locale, dict(zip(labels.values(), labels.values()))
    return translator.translate_locale(locale, list(labels.values()))

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        values = dict(pool.map(prepare, locales))
    path = ROOT / 'AdVoid/Localizable.xcstrings'
    data = json.loads(path.read_text())
    for key, source in labels.items():
        entry = data['strings'][key]
        entry['comment'] = 'Count label followed by a number; use a label, not a quantity-dependent noun phrase. Lookups are DNS requests, not website visits.'
        for locale in locales:
            entry.setdefault('localizations', {})[locale] = {'stringUnit': {'state': 'translated', 'value': values[locale][source]}}
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
