#!/usr/bin/env python3
"""Fill missing app strings with machine translations. Never overwrite existing translations.

Uses Google's public translation endpoint for public app copy only. New copy requires
native-speaker review before release. Cached responses make interrupted runs resumable.
Run validate-localizations.py and Apple's catalog compiler after importing.
"""
import concurrent.futures
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'AdVoid/Localizable.xcstrings'
CACHE = Path('/tmp/advoid-localization-translations')
CACHE.mkdir(exist_ok=True)
FORMAT = re.compile(r'%(?:\d+\$)?(?:lld|ld|lu|llu|@|d|u|f)')
# Preserve brands, DNS syntax and example hostnames exactly.
PROTECTED = re.compile(r'AdVoid|AdGuard|Cloudflare(?: Family| Security)?|iCloud Private Relay|YouTube|iPhone|Safari|AirPlay|Bonjour|OpenWrt|Ubiquiti|iOS|DNS|VPN|Wi-Fi|(?:0\.0\.0\.0|ads\.example\.com|https://|\*\.domain|\|\|domain\^|wpad|router)')

TRANSLATION_OVERRIDES = {
    'tr': {"AdGuard's list for DNS-level ad and tracker blocking.":
           'AdGuard’ın DNS düzeyinde reklam ve izleyici engelleme listesi.'}
}

def signature(value):
    result = []
    for index, token in enumerate(FORMAT.findall(value), 1):
        match = re.fullmatch(r'%(?:(\d+)\$)?(.*)', token)
        result.append((int(match[1]) if match[1] else index, match[2]))
    return sorted(result)

def translate_batch(locale, rows):
    encoded, replacements = [], []
    for row_index, key in enumerate(rows):
        tokens = []
        argument = 0
        def mask(match):
            nonlocal argument
            token = f'ZXQ{row_index * 100 + len(tokens)}QXZ'
            original = match.group()
            if FORMAT.fullmatch(original):
                argument += 1
                if '$' not in original:
                    original = f'%{argument}$' + original[1:]
            tokens.append((token, original))
            return token
        encoded.append(PROTECTED.sub(mask, FORMAT.sub(mask, key)))
        replacements.append(tokens)
    target = {'zh-Hans': 'zh-CN', 'zh-Hant': 'zh-TW', 'nb': 'no', 'pt-PT': 'pt', 'pt-BR': 'pt'}.get(locale, locale)
    query = urllib.parse.urlencode(dict(client='gtx', sl='en', tl=target, dt='t', q='\n'.join(encoded)))
    for attempt in range(5):
        try:
            request = urllib.request.Request('https://translate.googleapis.com/translate_a/single?' + query,
                                             headers={'User-Agent': 'AdVoid localization preparation'})
            response = json.load(urllib.request.urlopen(request, timeout=40))
            values = ''.join(x[0] or '' for x in response[0]).split('\n')
            if len(values) != len(rows):
                if len(rows) > 1:
                    return {k: v for key in rows for k, v in translate_batch(locale, [key]).items()}
                raise ValueError(f'Expected {len(rows)} rows, got {len(values)}')
            result = {}
            for key, value, tokens in zip(rows, values, replacements):
                for token, original in tokens:
                    pattern = re.compile(re.escape(token), re.I)
                    if not pattern.search(value):
                        raise ValueError(f'{locale}: missing token {token} in {key!r}: {value}')
                    value = pattern.sub(lambda _: original, value)
                if signature(key) != signature(value):
                    raise ValueError(f'{locale}: placeholders differ: {key!r}: {value}')
                result[key] = value.strip()
            return result
        except Exception:
            if attempt == 3 and len(rows) > 1:
                return {k: v for key in rows for k, v in translate_batch(locale, [key]).items()}
            if attempt == 4: raise
            time.sleep(1 + attempt * 2)

def translate_locale(locale, keys):
    path = CACHE / f'{locale}.json'
    cached = json.loads(path.read_text()) if path.exists() else {}
    cached.update({k: v for k, v in TRANSLATION_OVERRIDES.get(locale, {}).items() if k in keys})
    # Earlier cache versions lacked argument positions. Re-fetch multi-value strings.
    for key in keys:
        if len(FORMAT.findall(key)) > 1 and key in cached and '$' not in cached[key]:
            del cached[key]
    pending = [k for k in keys if k not in cached]
    for start in range(0, len(pending), 10):
        cached.update(translate_batch(locale, pending[start:start + 10]))
        path.write_text(json.dumps(cached, ensure_ascii=False, indent=2) + '\n')
    print(f'{locale}: {len(keys)} strings ready', flush=True)
    return locale, cached

def main():
    data = json.loads(CATALOG.read_text())
    locales = [r['bundle'] for r in json.loads((ROOT / 'scripts/localization-locales.json').read_text()) if r['bundle'] != 'en']
    jobs = {locale: [k for k, entry in data['strings'].items()
                     if entry.get('shouldTranslate', True) and
                     ((len(FORMAT.findall(k)) > 1) if '--repair-placeholders' in sys.argv
                      else locale not in entry.get('localizations', {}))]
            for locale in locales}
    if '--repair-placeholders' in sys.argv:
        # Keep established German/French/Spanish wording; only add argument positions.
        for locale in ['de', 'fr', 'es']:
            for key in jobs[locale]:
                unit = data['strings'][key]['localizations'][locale]['stringUnit']
                argument = [0]
                def position(match):
                    argument[0] += 1
                    return match.group() if '$' in match.group() else f'%{argument[0]}$' + match.group()[1:]
                unit['value'] = FORMAT.sub(position, unit['value'])
            jobs[locale] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        futures = [pool.submit(translate_locale, locale, keys) for locale, keys in jobs.items() if keys]
        for future in concurrent.futures.as_completed(futures):
            locale, values = future.result()
            for key in jobs[locale]:
                data['strings'][key].setdefault('localizations', {})[locale] = {
                    'stringUnit': {'state': 'translated', 'value': values[key]}}
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    report = {'method': 'Machine translation; native-speaker review outstanding',
              'newStrings': {locale: len(keys) for locale, keys in jobs.items() if keys}}
    report_path = ROOT / 'output/localization/translation-provenance.json'
    if '--repair-placeholders' in sys.argv and report_path.exists():
        report = json.loads(report_path.read_text()) | {'positionalPlaceholderRepair': True}
    report_path.write_text(json.dumps(report, indent=2) + '\n')

if __name__ == '__main__': main()
