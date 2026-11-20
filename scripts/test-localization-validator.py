#!/usr/bin/env python3
import copy
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('validator', ROOT / 'scripts/validate-localizations.py')
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)

class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / 'AdVoid/Localizable.xcstrings').read_text())
        self.inventory = json.loads((ROOT / 'scripts/localization-locales.json').read_text())

    def errors(self): return v.validate(self.catalog, self.inventory)[0]

    def test_catalog_passes(self): self.assertEqual(self.errors(), [])

    def test_missing_locale_is_reported(self):
        del self.catalog['strings']['Home']['localizations']['ar']
        self.assertIn("ar / 'Home': missing translation", self.errors())

    def test_wrong_placeholder_type_is_reported(self):
        self.catalog['strings']['%lld blocked']['localizations']['ur']['stringUnit']['value'] = 'Blocked: %@'
        self.assertTrue(any('ur' in e and 'placeholder mismatch' in e for e in self.errors()))

    def test_reordered_positional_arguments_are_safe(self):
        self.assertEqual(v.signature('%@ %lld'), v.signature('%2$lld %1$@'))
        self.assertNotEqual(v.signature('%@ %lld'), v.signature('%1$lld %2$@'))

    def test_untranslated_brand_and_hebrew_are_rejected(self):
        self.catalog['strings']['AdVoid']['localizations'] = {'he': {'stringUnit': {'state': 'translated', 'value': 'AdVoid'}}}
        self.assertTrue(any('unexpected locales' in e for e in self.errors()))
        self.assertTrue(any('intentionally untranslated' in e for e in self.errors()))

    def test_unreviewed_state_is_reported(self):
        self.catalog['strings']['Home']['localizations']['ar']['stringUnit']['state'] = 'needs_review'
        self.assertTrue(any('ar' in e and 'unreviewed state' in e for e in self.errors()))

    def test_plural_requires_other_and_valid_placeholders(self):
        unit = {'stringUnit': {'state': 'translated', 'value': '%lld lookup'}}
        entry = self.catalog['strings']['%lld lookups']['localizations']
        entry['en'] = {'variations': {'plural': {'one': unit}}}
        self.assertTrue(any('invalid plural categories' in e for e in self.errors()))
        entry['en']['variations']['plural']['other'] = copy.deepcopy(unit)
        self.assertEqual(self.errors(), [])
        entry['en']['variations']['plural']['other']['stringUnit']['value'] = '%@ lookups'
        self.assertTrue(any('placeholder mismatch' in e for e in self.errors()))

if __name__ == '__main__': unittest.main()
