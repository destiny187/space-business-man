"""Compose actual Blender/Godot captures for the selective INK revision."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'docs/production/media/ink-life'
fontfile=str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf')
def font(n):
 f=ImageFont.truetype(fontfile,n)
 try:f.set_variation_by_axes([550])
 except Exception:pass
 return f
forms=json.loads((P/'baseline.json').read_text())['forms'];families=json.loads((P/'selection.json').read_text())['families']
board=Image.new('RGB',(1440,100+len(families)*440),'#efeee2');d=ImageDraw.Draw(board);d.text((36,24),'기존 기본형',font=font(32),fill='#233b40');d.text((756,24),'선별 개선 · 현재 INK',font=font(32),fill='#233b40')
for i,fam in enumerate(families):
 f=next(x for x in forms if x['family']==fam)
 for j,folder in enumerate(['before','game']):
  path=P/folder/(f['id']+'.png');pic=Image.open(path).convert('RGB').crop((0,220,1440,1110));pic.thumbnail((720,390),Image.Resampling.LANCZOS);board.paste(pic,(j*720+(720-pic.width)//2,100+i*440))
 d.text((36,100+i*440+394),f['family_name']+' / '+f['id'],font=font(23),fill='#233b40')
board.save(P/'life-comparison.jpg',quality=95)
# One actual source render per changed structural family.
source=Image.new('RGB',(1200,1100),'#efeee2');d=ImageDraw.Draw(source)
for i,fam in enumerate(families):
 f=next(x for x in forms if x['family']==fam);pic=Image.open(P/'blender'/(f['id']+'.png')).convert('RGB');pic.thumbnail((300,240));x=i%4*300;y=i//4*550;source.paste(pic,(x,y));d.text((x+10,y+250),f['family_name'],font=font(20),fill='#233b40')
 for j,mode in enumerate(['shade','backlight']):
  pic=Image.open(P/'lighting'/(fam+'-'+mode+'.png')).convert('RGB');pic.thumbnail((150,230));source.paste(pic,(x+j*150,y+295))
source.save(P/'source-lighting-review.jpg',quality=94)
print('INK_REVIEW_BOARDS',len(families))
