from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from eye_designs import EYE_DESIGNS
ROOT=Path(__file__).resolve().parents[2];base=ROOT/'docs/production/media/bestiary';dest=base/'eye-revision'
forms={r['id']:r for r in json.load(open(ROOT/'우주-비즈니스/data/bestiary/forms.json'))['forms']};ids=list(EYE_DESIGNS)
f=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),19);f.set_variation_by_axes([600])
for start in [0,4]:
 board=Image.new('RGB',(1440,1160),'#efeee2');d=ImageDraw.Draw(board)
 for col,label in enumerate(['주광','그늘','역광','원거리 형상','공격 동작·효과']):d.text((col*288+12,12),label,font=f,fill='#233b40')
 for i,id in enumerate(ids[start:start+4]):
  row=forms[id];y=55+i*275
  paths=[ROOT/'우주-비즈니스/assets/ui/previews'/f'{id}.png',base/'lighting'/f'{id}-shade.png',base/'lighting'/f'{id}-backlight.png',base/'lod'/f'{id}.png']
  for col,path in enumerate(paths):
   im=Image.open(path).convert('RGB');im.thumbnail((288,240),Image.Resampling.LANCZOS);board.paste(im,(col*288,y))
  if row['attack']!='none':
   im=Image.open(dest/'attacks'/f"{row['family']}-active.png").convert('RGB').crop((40,220,1170,875));im.thumbnail((288,240),Image.Resampling.LANCZOS);board.paste(im,(1152,y+25))
  else:d.text((1180,y+100),'비공격형',font=f,fill='#233b40')
  d.text((12,y+240),row['name'],font=f,fill='#233b40')
 board.save(dest/f'review-{start//4+1}.jpg',quality=92)
print('EYE_REVIEW_BOARDS 2')
