#!/usr/bin/env python3
"""Localize the approved Charles sample; real captured UI is kept unchanged."""
import json,re,html,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=root/'output/charles-samples/en-editorial'
out=root/'output/charles-localized'
copy=json.loads((root/'output/app-store-calm/localizations.json').read_text())
hooks={
'en':'Less tracking.|More control.',
'ar-SA':'تتبع أقل.|تحكم أكبر.',
'bn-BD':'কম ট্র্যাকিং।|আরও নিয়ন্ত্রণ।',
'ca':'Menys seguiment.|Més control.',
'zh-Hans':'更少追踪。|更多掌控。',
'zh-Hant':'更少追蹤。|更多掌控。',
'hr':'Manje praćenja.|Više kontrole.',
'cs':'Méně sledování.|Více kontroly.',
'da':'Mindre sporing.|Mere kontrol.',
'nl-NL':'Minder tracking.|Meer controle.',
'fi':'Vähemmän seurantaa.|Enemmän hallintaa.',
'fr-FR':'Moins de suivi.|Plus de contrôle.',
'fr-CA':'Moins de suivi.|Plus de contrôle.',
'de-DE':'Weniger Tracking.|Mehr Kontrolle.',
'el':'Λιγότερη παρακολούθηση.|Περισσότερος έλεγχος.',
'gu-IN':'ઓછું ટ્રેકિંગ.|વધુ નિયંત્રણ.',
'hi':'कम ट्रैकिंग।|ज़्यादा नियंत्रण।',
'hu':'Kevesebb követés.|Több irányítás.',
'id':'Lebih sedikit pelacakan.|Lebih banyak kendali.',
'it':'Meno tracciamento.|Più controllo.',
'ja':'追跡を減らす。|自分で管理。',
'kn-IN':'ಕಡಿಮೆ ಟ್ರ್ಯಾಕಿಂಗ್.|ಹೆಚ್ಚಿನ ನಿಯಂತ್ರಣ.',
'ko':'추적은 줄이고.|제어는 늘리고.',
'ms':'Kurang penjejakan.|Lebih kawalan.',
'ml-IN':'കുറഞ്ഞ ട്രാക്കിംഗ്.|കൂടുതൽ നിയന്ത്രണം.',
'mr-IN':'कमी ट्रॅकिंग.|अधिक नियंत्रण.',
'no':'Mindre sporing.|Mer kontroll.',
'or-IN':'କମ୍ ଟ୍ରାକିଂ।|ଅଧିକ ନିୟନ୍ତ୍ରଣ।',
'pl':'Mniej śledzenia.|Więcej kontroli.',
'pt-BR':'Menos rastreamento.|Mais controle.',
'pt-PT':'Menos rastreio.|Mais controlo.',
'pa-IN':'ਘੱਟ ਟਰੈਕਿੰਗ।|ਵੱਧ ਕੰਟਰੋਲ।',
'ro':'Mai puțină urmărire.|Mai mult control.',
'ru':'Меньше отслеживания.|Больше контроля.',
'sk':'Menej sledovania.|Viac kontroly.',
'sl-SI':'Manj sledenja.|Več nadzora.',
'es-MX':'Menos rastreo.|Más control.',
'es-ES':'Menos rastreo.|Más control.',
'sv':'Mindre spårning.|Mer kontroll.',
 'ta-IN':'குறைவான கண்காணிப்பு.|அதிக கட்டுப்பாடு.',
 'te-IN':'తక్కువ ట్రాకింగ్.|ఎక్కువ నియంత్రణ.',
 'th':'ติดตามน้อยลง|ควบคุมได้มากขึ้น',
 'tr':'Daha az takip.|Daha fazla kontrol.',
 'uk':'Менше відстеження.|Більше контролю.',
 'ur-PK':'کم ٹریکنگ۔|زیادہ کنٹرول۔',
 'vi':'Ít theo dõi hơn.|Kiểm soát nhiều hơn.'}
assert len(copy)==49 and 'he' not in copy
out.mkdir(exist_ok=True)
# Shared local assets keep each HTML self-contained within the output tree.
for name in ['fonts','ui']:
 shutil.copytree(src/name,out/name,dirs_exist_ok=True)
shutil.copy2(src/'base.css',out/'base.css')
base=(src/'set.html').read_text()
manifest={}
for locale,item in copy.items():
 d=out/locale;d.mkdir(exist_ok=True)
 hook=hooks['en' if locale.startswith('en-') else locale].split('|')
 heads=hook+item['headlinesV3'][1:]
 if locale=='ml-IN': heads[2:]=['തടഞ്ഞവ കാണാം.', 'നിങ്ങളുടെ പട്ടികകൾ.']
 text=base.replace('lang="en"',f'lang="{locale}"')
 text=text.replace('href="base.css"','href="../base.css"').replace('href="fonts/','href="../fonts/').replace('src="ui/','src="../ui/')
 it=iter(heads)
 text=re.sub(r'(<h[12] class="hd[^>]*>).*?(</h[12]>)',lambda m:m[1]+'<em>'+html.escape(next(it)).replace('\n','<br>')+'</em>'+m[2],text)
 # Short verified product fact, already localized in the store copy.
 text=text.replace('On-device ad &amp; tracker blocking',html.escape(item['subtitle']))
 text=text.replace('Your history stays on-device',html.escape(item['subtitle']))
 text=text.replace('AdVoid Pro required · Example activity',html.escape(item['footnote']))
 rtl=locale in ['ar-SA','ur-PK']
 text=text.replace('</style>', '\n.hd,.fact,.disclosure{font-family:"Inter Tight","Noto Sans",sans-serif;letter-spacing:normal;overflow-wrap:normal;direction:'+('rtl' if rtl else 'ltr')+'} .hd em{color:inherit} .hd.hook em{color:var(--accent)} .hd.dark em{color:var(--mint)}\n</style>')
 text=text.replace('</body>', '''<script>
window.fitReady=document.fonts.ready.then(()=>{
 for(const e of document.querySelectorAll('.hd')){
  let size=e.classList.contains('hook')?80:54; const budget=e.classList.contains('hook')?170:150;
  e.style.fontSize=size+'px';
  while((e.getBoundingClientRect().height>budget || e.scrollWidth>368)&&size>40){size--;e.style.fontSize=size+'px'}
  if(e.getBoundingClientRect().height>budget || e.scrollWidth>368)throw Error('Headline overflow');
 }
 for(const e of document.querySelectorAll('.fact,.disclosure')){
  if(e.getBoundingClientRect().height>65)throw Error('Small copy overflow');
 }
});</script></body>''')
 (d/'set.html').write_text(text)
 (d/'brief.md').write_text((src/'brief.md').read_text()+f'\nLocalization: {locale}. Machine translation; native review pending. Real UI remains English; this is a store-only localization.\n')
 manifest[locale]={'language':item['language'],'headlines':heads,'controlSearchCover':f'output/app-store-calm/search-cards/{locale}.png','treatmentSearchCover':f'output/charles-localized/{locale}/search-cover.png','reviewStatus':'machine translated; native review pending','control':f'output/app-store-calm/screenshots-v3/{locale}','treatment':f'output/charles-localized/{locale}/frames'}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Prepared',len(manifest),'locales; Hebrew excluded')
