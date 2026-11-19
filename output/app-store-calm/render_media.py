#!/usr/bin/python3
"""Device exports and native search-results artwork, using existing app captures."""
import json, sys
from pathlib import Path
from device import draw_iphone
from render_v3 import cairo, color, rounded, text, ROOT, CAPTURES
D=json.loads((ROOT/'localizations.json').read_text())

def phone(ctx,path,x,y,width):
 shot=cairo.ImageSurface.create_from_png(str(path));sw,sh=shot.get_width(),shot.get_height();height=width*sh/sw
 draw_iphone(ctx,shot,x,y,width)

def render(locale,e):
 out=ROOT/'screenshots-v3'/locale
 # Render the composition into each device aspect ratio; no source UI is redrawn.
 for size in [(1242,2688),(1206,2622)]:
  folder=out/f'{size[0]}x{size[1]}';folder.mkdir(exist_ok=True)
  for i,name in enumerate(['home','activity','settings']):
   source=cairo.ImageSurface.create_from_png(str(out/f'{i+1:02d}-{name}.png'))
   s=cairo.ImageSurface(cairo.FORMAT_RGB24,*size);c=cairo.Context(s);color(c,'#FFFFFF');c.paint()
   scale=min(size[0]/source.get_width(),size[1]/source.get_height());c.translate((size[0]-source.get_width()*scale)/2,(size[1]-source.get_height()*scale)/2);c.scale(scale,scale);c.set_source_surface(source,0,0);c.paint();s.write_to_png(str(folder/f'{i+1:02d}-{name}.png'))
 # Search-results creative asset: 3840 x 2560, 3:2.
 folder=ROOT/'search-cards';folder.mkdir(exist_ok=True)
 s=cairo.ImageSurface(cairo.FORMAT_RGB24,3840,2560);c=cairo.Context(s);color(c,'#FFFFFF');c.paint()
 text(c,'AdVoid',260,240,1800,115,'#202124',600,maxheight=170)
 text(c,e['headlinesV3'][0],260,650,1830,220,'#202124',700,maxheight=1020)
 text(c,e['footnote'],260,2030,1600,55,'#617469',400,maxheight=340)
 lang={'de-DE':'de','fr-FR':'fr','fr-CA':'fr','es-ES':'es','es-MX':'es'}.get(locale,'')
 phone(c,CAPTURES/lang/'home.png',2360,240,1130)
 s.write_to_png(str(folder/f'{locale}.png'))
if __name__=='__main__':
 chosen=list(D) if len(sys.argv)>1 and sys.argv[1]=='all' else [sys.argv[1] if len(sys.argv)>1 else 'en-US']
 for locale in chosen:render(locale,D[locale])
 print(f'Rendered device exports, search cards for {len(chosen)} locales.')
