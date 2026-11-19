#!/usr/bin/python3
"""Render real AdVoid captures with typeset localized captions. No generated UI.
Linux: /usr/bin/python3 render.py [en-US|all] (python3-gi, python3-cairo, Pango).
Outputs 1290x2796 PNGs; text uses Pango shaping and font fallback for RTL/Indic/CJK.
"""
import json, math, sys, unicodedata
from pathlib import Path
import gi
import os
if os.environ.get('GI_CAIRO_PATH'): gi.__path__.append(os.environ['GI_CAIRO_PATH'])
gi.require_foreign('cairo')
gi.require_version('Pango', '1.0'); gi.require_version('PangoCairo', '1.0')
from gi.repository import Pango, PangoCairo
import cairo
from device import draw_iphone
ROOT=Path(__file__).parent
CAPTURES=ROOT.parent/'app-store-screenshots'/'source-captures'
W,H=1290,2796

def color(ctx, value):
    ctx.set_source_rgb(*(int(value[i:i+2],16)/255 for i in (1,3,5)))

def rounded(ctx,x,y,w,h,r):
    ctx.new_sub_path()
    for cx,cy,a in [(x+w-r,y+r,-90),(x+w-r,y+h-r,0),(x+r,y+h-r,90),(x+r,y+r,180)]:
        ctx.arc(cx,cy,r,math.radians(a),math.radians(a+90))
    ctx.close_path()

def text(ctx, value, x,y,width,size,ink,weight=400,maxheight=300, align='left'):
    while True:
        layout=PangoCairo.create_layout(ctx)
        # Compact Latin/Greek/Cyrillic typography; preserve native shaping elsewhere.
        compact=all(not ch.isalpha() or unicodedata.name(ch,'').startswith(('LATIN','GREEK','CYRILLIC')) for ch in value)
        desc=Pango.FontDescription('Lato, Noto Sans' if compact else 'Noto Sans')
        desc.set_absolute_size(size*Pango.SCALE);desc.set_weight(weight)
        layout.set_font_description(desc);layout.set_width(int(width*Pango.SCALE))
        layout.set_wrap(Pango.WrapMode.WORD_CHAR);layout.set_spacing(int(size*.06*Pango.SCALE))
        layout.set_auto_dir(True)
        layout.set_alignment(Pango.Alignment.CENTER if align=='center' else Pango.Alignment.LEFT)
        layout.set_text(value,-1)
        if compact and weight>=600:
            attributes=Pango.AttrList()
            attributes.insert(Pango.attr_letter_spacing_new(int(-0.025*size*Pango.SCALE)))
            layout.set_attributes(attributes)
            layout.set_spacing(0)
            layout.set_line_spacing(0.96)
        tw,th=layout.get_pixel_size()
        if th<=maxheight and tw<=width+1:break
        size-=1
        if size<28:raise ValueError(f'Text overflow: {value}')
    color(ctx,ink);ctx.move_to(x,y);PangoCairo.show_layout(ctx,layout)
    return {'size':size,'height':th,'text':value}

def render(locale, entry):
    out=ROOT/'screenshots-v3'/locale;out.mkdir(parents=True,exist_ok=True)
    lang={'de-DE':'de','fr-FR':'fr','fr-CA':'fr','es-ES':'es','es-MX':'es'}.get(locale)
    audit=[]
    for i,screen in enumerate(['home','activity','settings']):
        surface=cairo.ImageSurface(cairo.FORMAT_RGB24,W,H);ctx=cairo.Context(surface)
        color(ctx,'#FFFFFF');ctx.paint()
        text(ctx,'AdVoid',96,85,1098,54,'#202124',600,maxheight=90,align='center')
        titles=entry.get('headlinesV3',entry['headlines'])
        audit.append(text(ctx,titles[i],80,223,1130,115,'#202124',700,maxheight=330,align='center'))
        shot=cairo.ImageSurface.create_from_png(str(CAPTURES/(lang or '')/(screen+'.png')))
        sw,sh=shot.get_width(),shot.get_height(); width=900; height=width*sh/sw
        x=(W-width)/2;y=650
        draw_iphone(ctx,shot,x,y,width)
        if True:
            # A magnified fact from the supplied demo capture, not a new feature.
            cy=1670 if i==0 else 1900
            color(ctx,'#E9EAEC');rounded(ctx,112,cy+6,1066,256,42);ctx.fill()
            color(ctx,'#FFFFFF');rounded(ctx,110,cy,1070,250,42);ctx.fill_preserve();color(ctx,'#E5E6E8');ctx.set_line_width(2);ctx.stroke()
            labels=[('122',entry['labels'][0]),(entry['labels'][1],'googleads.g.doubleclick.net'),(entry['labels'][2],'HaGeZi Pro · OISD Small')]
            main,sub=labels[i]
            text(ctx,main,160,cy+25,970,82 if i==0 else 64,'#202124',700,maxheight=110)
            text(ctx,sub,160,cy+140,970,34,'#77787D',400,maxheight=75)
        text(ctx,entry['footnote'],96,2658,1098,29,'#617469',400,maxheight=90,align='center')
        filename=f'{i+1:02d}-{screen}.png';surface.write_to_png(str(out/filename))
    return audit
if __name__=='__main__':
    data=json.loads((ROOT/'localizations.json').read_text())
    chosen=list(data) if len(sys.argv)>1 and sys.argv[1]=='all' else [sys.argv[1] if len(sys.argv)>1 else 'en-US']
    audit={locale:render(locale,data[locale]) for locale in chosen}
    (ROOT/'render-audit-v3.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
    print(f'Rendered {len(chosen)*3} PNGs at {W}x{H}.')
