from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'docs/production/media/bestiary'
forms=json.load(open(ROOT/'우주-비즈니스/data/bestiary/forms.json'))['forms']
f=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),22)
f.set_variation_by_axes([600])
aberrant_only='--aberrant' in sys.argv
output=p/'aberrant' if aberrant_only else p
if aberrant_only:forms=[r for r in forms if r.get('collection')=='aberrant']
representatives=list({r['family']:next(x for x in forms if x['family']==r['family']) for r in forms}.values())
attacks=json.load(open(output/'attacks/captures.json'))
for start in range(0,len(attacks),5):
 board=Image.new('RGB',(1440,85+len(attacks[start:start+5])*345),'#efeee2');d=ImageDraw.Draw(board)
 for col,name in enumerate(['공격 전조','공격 동작과 효과','회복']):d.text((col*480+20,12),name,font=f,fill='#233b40')
 for i,row in enumerate(attacks[start:start+5]):
  for col,state in enumerate(['windup','active','recovery']):
   im=Image.open(output/'attacks'/f"{row['family']}-{state}.png").convert('RGB').crop((40,220,1170,875));im.thumbnail((480,300),Image.Resampling.LANCZOS)
   board.paste(im,(col*480,65+i*345));d.text((col*480+20,365+i*345),row['family']+' / '+row['attack'],font=f,fill='#233b40')
 board.save(output/f'attack-board-{start//5+1}.jpg',quality=92)
for start in range(0,len(representatives),5):
 board=Image.new('RGB',(1920,2220),'#efeee2');d=ImageDraw.Draw(board)
 for col,name in enumerate(['주광','그늘','역광','원거리용 형상']):d.text((col*480+20,10),name,font=f,fill='#233b40')
 for i,fm in enumerate(representatives[start:start+5]):
  paths=[ROOT/'우주-비즈니스/assets/ui/previews'/f"{fm['id']}.png",p/'lighting'/f"{fm['id']}-shade.png",p/'lighting'/f"{fm['id']}-backlight.png",p/'lod'/f"{fm['id']}.png"]
  for col,path in enumerate(paths):
   board.paste(Image.open(path).convert('RGB'),(col*480,55+i*430))
   d.text((col*480+15,452+i*430),fm['family_name'],font=f,fill='#233b40')
 board.save(output/f'lighting-board-{start//5+1}.jpg',quality=92)
print('REVIEW_BOARDS_COMPLETE')
