#!/usr/bin/env python3
"""Validate app catalog coverage and format safety without a network connection."""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r'%(?:(\d+)\$)?([-+#0 ]*\d*(?:\.\d+)?)(hh|ll|h|l|L|z|t|j)?([@diuoxXfFeEgGaAcCsSp%])')
PLURALS = {'zero', 'one', 'two', 'few', 'many', 'other'}

def signature(text):
    result, position = [], 1
    for match in TOKEN.finditer(text):
        index, _, length, kind = match.groups()
        if kind == '%': continue
        result.append((int(index) if index else position, (length or '') + kind))
        position += 1
    return sorted(result)

def units(node, location, errors):
    if 'stringUnit' in node:
        unit = node['stringUnit']
        if unit.get('state') != 'translated': errors.append(f'{location}: unreviewed state {unit.get("state")}')
        if not isinstance(unit.get('value'), str) or not unit['value'].strip(): errors.append(f'{location}: empty string')
        yield unit.get('value', '')
    elif 'variations' in node:
        for axis, variants in node['variations'].items():
            if axis == 'plural' and ('other' not in variants or set(variants) - PLURALS):
                errors.append(f'{location}: invalid plural categories {list(variants)}')
            for name, child in variants.items():
                yield from units(child, f'{location}/{axis}/{name}', errors)
    else:
        errors.append(f'{location}: expected stringUnit or variations')

def validate(catalog, inventory):
    errors = []
    expected = {row['bundle'] for row in inventory}
    if len(expected) != 49 or 'en' not in expected: errors.append('Inventory must contain 49 unique locales including en')
    if catalog.get('sourceLanguage') != 'en': errors.append('Source language must be en')
    strings = catalog['strings']
    coverage = collections.Counter()
    for key, entry in strings.items():
        locations = entry.get('localizations', {})
        unexpected = set(locations) - expected
        if unexpected: errors.append(f'{key!r}: unexpected locales {sorted(unexpected)}')
        if entry.get('shouldTranslate') is False:
            if locations: errors.append(f'{key!r}: intentionally untranslated key has translations')
            continue
        if entry.get('extractionState') == 'stale': errors.append(f'{key!r}: stale key needs review')
        for locale in sorted(expected - {'en'}):
            if locale not in locations:
                errors.append(f'{locale} / {key!r}: missing translation')
        for locale, node in locations.items():
            coverage[locale] += 1
            for value in units(node, f'{locale} / {key!r}', errors):
                if signature(key) != signature(value):
                    errors.append(f'{locale} / {key!r}: placeholder mismatch {signature(value)}, expected {signature(key)}')
                if re.search(r'ZXQ\d+QXZ', value, re.I): errors.append(f'{locale} / {key!r}: translation token left over')
    return errors, dict(sorted(coverage.items()))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path, default=ROOT / 'AdVoid/Localizable.xcstrings')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text())
    errors, coverage = validate(catalog, json.loads((ROOT / 'scripts/localization-locales.json').read_text()))
    report = {'passed': not errors, 'source': 'en', 'keys': len(catalog['strings']), 'coverage': coverage, 'errors': errors,
              'translationReview': 'Structural checks do not replace native-speaker review of machine translations.'}
    if args.report: args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    for error in errors: print(error)
    print(f'{"PASS" if not errors else "FAIL"}: {len(catalog["strings"])} keys, {len(set(coverage) - {"en"})} translated locales plus English; {len(errors)} errors')
    raise SystemExit(bool(errors))

if __name__ == '__main__': main()
