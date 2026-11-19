"""Deterministic black-titanium iPhone mockup around the real unmodified UI capture."""
import math

def rounded(ctx,x,y,w,h,r):
 ctx.new_sub_path()
 for cx,cy,a in [(x+w-r,y+r,-90),(x+w-r,y+h-r,0),(x+r,y+h-r,90),(x+r,y+r,180)]:ctx.arc(cx,cy,r,math.radians(a),math.radians(a+90))
 ctx.close_path()
def color(ctx,value):ctx.set_source_rgb(*(int(value[i:i+2],16)/255 for i in (1,3,5)))
def draw_iphone(ctx,shot,x,y,width):
 sw,sh=shot.get_width(),shot.get_height();height=width*sh/sw
 rim=width*.028;radius=width*.159
 # Separate side buttons, behind the titanium edge.
 for right,offset,length in [(False,.122,.035),(False,.192,.061),(False,.274,.061),(True,.215,.095)]:
  bx=x+width+rim-1 if right else x-rim-width*.007
  color(ctx,'#777572');rounded(ctx,bx,y+height*offset,width*.008,height*length,width*.0035);ctx.fill()
 # A restrained metallic edge, flat front glass and thin black screen bezel.
 color(ctx,'#777571');rounded(ctx,x-rim,y-rim,width+2*rim,height+2*rim,radius);ctx.fill()
 color(ctx,'#242523');rounded(ctx,x-rim+width*.004,y-rim+width*.004,width+2*rim-width*.008,height+2*rim-width*.008,radius-width*.004);ctx.fill()
 color(ctx,'#0A0B0B');rounded(ctx,x-width*.017,y-width*.017,width*1.034,height+width*.034,width*.15);ctx.fill()
 ctx.save();rounded(ctx,x,y,width,height,width*.137);ctx.clip()
 ctx.translate(x,y);ctx.scale(width/sw,height/sh);ctx.set_source_surface(shot,0,0);ctx.paint();ctx.restore()
 # Hardware island aligns with the untouched status bar in the source capture.
 iw=width*.302;ih=width*.081;ix=x+(width-iw)/2;iy=y+width*.024
 color(ctx,'#000000');rounded(ctx,ix,iy,iw,ih,ih/2);ctx.fill()
 # Camera lens inside the island, deliberately low contrast.
 ctx.arc(ix+iw-ih*.53,iy+ih*.5,ih*.155,0,math.tau);color(ctx,'#111820');ctx.fill()
 ctx.arc(ix+iw-ih*.53,iy+ih*.5,ih*.09,0,math.tau);color(ctx,'#0B1520');ctx.fill()
 return height
