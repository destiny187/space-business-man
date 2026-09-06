from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from eye_designs import EYE_DESIGNS
ROOT=Path(__file__).resolve().parents[2];base=ROOT/'docs/production/media/bestiary';dest=base/'eye-revision'
forms={r['id']:r for r in json.loads((ROOT/'우주-비즈니스/data/bestiary/forms.json').read_text())['forms']}
def font(size):
 f=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),size);f.set_variation_by_axes([600]);return f
rows=[]
for id,design in EYE_DESIGNS.items():
 x,y=json.loads((base/'records'/f'{id}.json').read_text())['head_pixel'];crops=[]
 for path in [dest/f'{id}-before.png',base/'models'/f'{id}.png']:
  im=Image.open(path).convert('RGB');crop=im.crop((round(x-240),round(y-210),round(x+220),round(y+170)));crop.thumbnail((540,430),Image.Resampling.LANCZOS);crops.append(crop)
 rows.append((id,design[2],crops))
for start in [0,4]:
 board=Image.new('RGB',(1160,1920),'#efeee2');d=ImageDraw.Draw(board)
 d.text((30,20),'기존 생물 / 눈 수정 전 → 후',font=font(32),fill='#233b40')
 for i,(id,label,crops) in enumerate(rows[start:start+4]):
  y=90+i*450
  for col,im in enumerate(crops):board.paste(im,(col*580+(580-im.width)//2,y))
  d.text((28,y+390),forms[id]['name']+'  ·  '+label,font=font(21),fill='#233b40')
 board.save(dest/f'before-after-{start//4+1}.jpg',quality=94)
hero=Image.new('RGB',(1600,890),'#efeee2');d=ImageDraw.Draw(hero)
d.text((30,18),'기존 생물 8개 / 눈과 감각기관 수정',font=font(34),fill='#233b40')
for i,(id,label,crops) in enumerate(rows):
 im=crops[1];im=im.resize((380,314),Image.Resampling.LANCZOS);x=(i%4)*400;y=100+(i//4)*390;hero.paste(im,(x+10,y))
 d.text((x+15,y+318),forms[id]['family_name'],font=font(21),fill='#233b40')
 d.text((x+15,y+350),label,font=font(15),fill='#4c655c')
hero.save(dest/'overview.jpg',quality=94)
print('EYE_COMPARISON_COMPLETE',len(rows))
