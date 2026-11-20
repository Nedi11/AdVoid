#!/usr/bin/env python3
from pathlib import Path
import json,re
from playwright.sync_api import sync_playwright
root=Path(__file__).resolve().parents[1]/'output/charles-localized'
with sync_playwright() as p:
 b=p.chromium.launch();page=b.new_page(viewport={'width':1280,'height':854},device_scale_factor=3)
 for locale in json.loads((root/'manifest.json').read_text()):
  d=root/locale;text=(d/'set.html').read_text()
  css='''<style>
.strip{width:1280px!important;height:853.333333px!important;background:var(--paper)}
.frame{width:1280px!important;height:853.333333px!important}
.frame:not(:first-child),.dark-ground,.last-ground,.footer-band{display:none!important}
.hook-ground{width:1280px!important;height:853.333333px!important}
.brand{left:60px!important;top:60px!important;font-size:42px}
.fact{left:60px!important;top:140px!important;max-width:650px!important;font-size:26px}
.hd.hook{left:60px!important;top:240px!important;width:650px!important;font-size:100px!important;line-height:1.05}
.phone{left:850px!important;top:62px!important}
.crop{left:780px!important;top:620px!important}
.disclosure{left:60px!important;top:745px!important;bottom:auto!important;width:650px!important;font-size:24px}
.trace{top:205px!important;left:-80px!important}
</style>'''
  # One search cover is a standalone landscape composition of the opening frame.
  text=text.replace('</head>',css+'</head>')
  text=text.replace('<script>','<script>document.querySelectorAll(".at").forEach(e=>{if(!e.style.getPropertyValue("--f").trim().match(/^1$/))e.remove()});',1)
  # Search composition has its own 650px headline measure and no portrait fitting loop.
  text=re.sub(r'window.fitReady=document.fonts.ready.then\(\(\)=>\{.*?\}\);','window.fitReady=document.fonts.ready;',text,flags=re.S)
  (d/'search-cover.html').write_text(text)
  page.goto((d/'search-cover.html').as_uri());page.evaluate('async()=>{await document.fonts.ready;await Promise.all([...document.images].map(i=>i.decode()))}')
  # Long scripts retain readable type, with bounded room before the device.
  page.locator('.hd').evaluate('(e)=>{let s=100;while((e.scrollWidth>650||e.getBoundingClientRect().height>340)&&s>56){s--;e.style.setProperty("font-size",s+"px","important")}}')
  page.screenshot(path=str(d/'search-cover.png'),clip={'x':0,'y':0,'width':1280,'height':2560/3})
 b.close()
print('Rendered 49 localized Charles search covers, 3840 x 2560')
