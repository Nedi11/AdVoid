#!/usr/bin/env python3
"""Geometry checks for every locale, including fallback fonts and RTL layout."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]/'output/charles-localized'
report=[]
with sync_playwright() as p:
 browser=p.chromium.launch()
 page=browser.new_page(viewport={'width':1760,'height':956})
 for locale in json.loads((root/'manifest.json').read_text()):
  errors=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto((root/locale/'set.html').as_uri())
  page.evaluate('async()=>{await window.fitReady;await document.fonts.ready}')
  items=page.locator('.hd').evaluate_all('els=>els.map(e=>({text:e.innerText,size:parseFloat(getComputedStyle(e).fontSize),height:e.getBoundingClientRect().height,width:e.scrollWidth,hook:e.classList.contains("hook")}))')
  for item in items:
   if item['size']<40 or item['width']>368 or item['height']>(170 if item['hook'] else 150):errors.append('Headline geometry: '+item['text'])
  report.append({'locale':locale,'errors':errors,'headlines':items})
 browser.close()
(root/'geometry-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'locales':len(report),'failed':[x['locale'] for x in report if x['errors']]}))
if any(x['errors'] for x in report):raise SystemExit(1)
