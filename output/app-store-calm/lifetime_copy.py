"""Keep version 1.2's purchase disclosure and release notes consistent."""
import json
from pathlib import Path
p=Path(__file__).parent/'localizations.json';d=json.loads(p.read_text())
rows='''
en-US|An AdVoid Pro subscription is required.|AdVoid Pro is required. A one-time lifetime purchase option has been added.
ar-SA|يلزم اشتراك AdVoid Pro.|يلزم AdVoid Pro. تمت إضافة خيار الشراء مدى الحياة بدفعة واحدة.
bn-BD|AdVoid Pro সাবস্ক্রিপশন প্রয়োজন।|AdVoid Pro প্রয়োজন। একবার অর্থ প্রদান করে আজীবন ব্যবহারের বিকল্প যোগ করা হয়েছে।
ca|Cal una subscripció a AdVoid Pro.|Cal AdVoid Pro. S'ha afegit una opció de compra de per vida amb un únic pagament.
zh-Hans|需要订阅 AdVoid Pro。|需要 AdVoid Pro。新增一次性购买的终身使用选项。
zh-Hant|需要訂閱 AdVoid Pro。|需要 AdVoid Pro。新增一次性購買的終身使用選項。
hr|Potrebna je pretplata na AdVoid Pro.|Potreban je AdVoid Pro. Dodana je mogućnost jednokratne kupnje doživotnog pristupa.
cs|Je vyžadováno předplatné AdVoid Pro.|Je vyžadován AdVoid Pro. Přidána možnost jednorázového nákupu doživotního přístupu.
da|Kræver et AdVoid Pro-abonnement.|Kræver AdVoid Pro. Der er tilføjet mulighed for livstidsadgang med en engangsbetaling.
nl-NL|Een AdVoid Pro-abonnement is vereist.|AdVoid Pro is vereist. Er is een eenmalige aankoopoptie voor levenslange toegang toegevoegd.
fi|AdVoid Pro -tilaus vaaditaan.|AdVoid Pro vaaditaan. Lisätty mahdollisuus ostaa elinikäinen käyttöoikeus kertamaksulla.
fr-FR|Un abonnement AdVoid Pro est requis.|AdVoid Pro est requis. Une option d'achat à vie avec paiement unique a été ajoutée.
de-DE|Ein AdVoid Pro-Abo ist erforderlich.|AdVoid Pro ist erforderlich. Eine Option zum einmaligen Kauf eines lebenslangen Zugangs wurde hinzugefügt.
el|Απαιτείται συνδρομή AdVoid Pro.|Απαιτείται AdVoid Pro. Προστέθηκε επιλογή εφάπαξ αγοράς για ισόβια πρόσβαση.
gu-IN|AdVoid Pro સબ્સ્ક્રિપ્શન જરૂરી છે.|AdVoid Pro જરૂરી છે. એક જ ચુકવણીથી આજીવન ઍક્સેસ ખરીદવાનો વિકલ્પ ઉમેરાયો છે.
hi|AdVoid Pro सदस्यता ज़रूरी है।|AdVoid Pro ज़रूरी है। एक बार भुगतान करके आजीवन इस्तेमाल का विकल्प जोड़ा गया है।
hu|AdVoid Pro-előfizetés szükséges.|AdVoid Pro szükséges. Egyszeri vásárlással elérhető, élethosszig tartó hozzáférési lehetőség került az appba.
id|Langganan AdVoid Pro diperlukan.|AdVoid Pro diperlukan. Opsi pembelian sekali bayar untuk akses seumur hidup telah ditambahkan.
it|È richiesto un abbonamento AdVoid Pro.|È richiesto AdVoid Pro. È stata aggiunta un'opzione di acquisto a vita con pagamento unico.
ja|AdVoid Proのサブスクリプションが必要です。|AdVoid Proが必要です。一度の購入で無期限に利用できるオプションを追加しました。
kn-IN|AdVoid Pro ಚಂದಾದಾರಿಕೆ ಅಗತ್ಯ.|AdVoid Pro ಅಗತ್ಯ. ಒಮ್ಮೆ ಪಾವತಿಸಿ ಜೀವಿತಾವಧಿ ಪ್ರವೇಶ ಪಡೆಯುವ ಆಯ್ಕೆ ಸೇರಿಸಲಾಗಿದೆ.
ko|AdVoid Pro 구독이 필요합니다.|AdVoid Pro가 필요합니다. 한 번 결제하면 평생 이용할 수 있는 구매 옵션이 추가되었습니다.
ms|Langganan AdVoid Pro diperlukan.|AdVoid Pro diperlukan. Pilihan pembelian sekali bayar untuk akses seumur hidup telah ditambahkan.
ml-IN|AdVoid Pro സബ്‌സ്‌ക്രിപ്‌ഷൻ ആവശ്യമാണ്.|AdVoid Pro ആവശ്യമാണ്. ഒറ്റത്തവണ പണമടച്ച് ആജീവനാന്ത ഉപയോഗത്തിനുള്ള ഓപ്ഷൻ ചേർത്തു.
mr-IN|AdVoid Pro सदस्यता आवश्यक आहे.|AdVoid Pro आवश्यक आहे. एकदाच पैसे भरून आजीवन वापरण्याचा पर्याय जोडला आहे.
no|Et AdVoid Pro-abonnement kreves.|AdVoid Pro kreves. Et alternativ for engangskjøp med livstidstilgang er lagt til.
or-IN|AdVoid Pro ସବସ୍କ୍ରିପସନ ଆବଶ୍ୟକ।|AdVoid Pro ଆବଶ୍ୟକ। ଥରେ ପୈଠ କରି ଆଜୀବନ ବ୍ୟବହାର ପାଇଁ କ୍ରୟ ବିକଳ୍ପ ଯୋଗ ହୋଇଛି।
pl|Wymagana jest subskrypcja AdVoid Pro.|Wymagany jest AdVoid Pro. Dodano opcję jednorazowego zakupu dożywotniego dostępu.
pt-BR|É necessária uma assinatura do AdVoid Pro.|É necessário o AdVoid Pro. Foi adicionada uma opção de compra vitalícia com pagamento único.
pt-PT|É necessária uma assinatura do AdVoid Pro.|É necessário o AdVoid Pro. Foi adicionada uma opção de compra vitalícia com pagamento único.
pa-IN|AdVoid Pro ਗਾਹਕੀ ਲੋੜੀਂਦੀ ਹੈ।|AdVoid Pro ਲੋੜੀਂਦਾ ਹੈ। ਇੱਕ ਵਾਰ ਭੁਗਤਾਨ ਕਰਕੇ ਉਮਰ ਭਰ ਵਰਤੋਂ ਦੀ ਖਰੀਦ ਦਾ ਵਿਕਲਪ ਜੋੜਿਆ ਗਿਆ ਹੈ।
ro|Este necesar un abonament AdVoid Pro.|Este necesar AdVoid Pro. A fost adăugată opțiunea de achiziție pe viață, cu o singură plată.
ru|Нужна подписка AdVoid Pro.|Нужен AdVoid Pro. Добавлена возможность единоразовой покупки пожизненного доступа.
sk|Vyžaduje sa predplatné AdVoid Pro.|Vyžaduje sa AdVoid Pro. Pridaná možnosť jednorazového nákupu doživotného prístupu.
sl-SI|Potrebna je naročnina AdVoid Pro.|Potreben je AdVoid Pro. Dodana je možnost enkratnega nakupa doživljenjskega dostopa.
es-ES|Se requiere una suscripción a AdVoid Pro.|Se requiere AdVoid Pro. Se ha añadido una opción de compra de por vida con un único pago.
es-MX|Se requiere una suscripción a AdVoid Pro.|Se requiere AdVoid Pro. Se agregó una opción de compra de por vida con un solo pago.
sv|En AdVoid Pro-prenumeration krävs.|AdVoid Pro krävs. Ett alternativ för engångsköp med livstidsåtkomst har lagts till.
ta-IN|AdVoid Pro சந்தா தேவை.|AdVoid Pro தேவை. ஒருமுறை பணம் செலுத்தி வாழ்நாள் அணுகலைப் பெறும் வசதி சேர்க்கப்பட்டுள்ளது.
te-IN|AdVoid Pro సభ్యత్వం అవసరం.|AdVoid Pro అవసరం. ఒకసారి చెల్లించి జీవితకాల యాక్సెస్ పొందే కొనుగోలు ఎంపిక జోడించబడింది.
th|ต้องสมัครสมาชิก AdVoid Pro|ต้องมี AdVoid Pro เพิ่มตัวเลือกซื้อครั้งเดียวเพื่อใช้งานตลอดชีพแล้ว
tr|AdVoid Pro aboneliği gerekir.|AdVoid Pro gerekir. Tek seferlik ödemeyle ömür boyu erişim satın alma seçeneği eklendi.
uk|Потрібна передплата AdVoid Pro.|Потрібен AdVoid Pro. Додано можливість одноразової купівлі довічного доступу.
ur-PK|AdVoid Pro سبسکرپشن ضروری ہے۔|AdVoid Pro ضروری ہے۔ ایک بار ادائیگی کے ساتھ تاحیات رسائی کی خریداری کا آپشن شامل کیا گیا ہے۔
vi|Cần đăng ký AdVoid Pro.|Cần AdVoid Pro. Đã thêm tùy chọn mua một lần để sử dụng trọn đời.
'''
for line in rows.strip().splitlines():
 locale,old,new=line.split('|')
 targets=[locale]+({'en-US':['en-AU','en-CA','en-GB'],'fr-FR':['fr-CA']}.get(locale,[]))
 for target in targets:
  assert old in d[target]['description'] or new in d[target]['description'],target
  d[target]['description']=d[target]['description'].replace(old,new)
  d[target]['whatsNew']=new.split('. ',1)[1] if '. ' in new else new
for e in d.values():e['footnote']=e['footnote'].replace('AdVoid Pro subscription required.','AdVoid Pro required.')
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
