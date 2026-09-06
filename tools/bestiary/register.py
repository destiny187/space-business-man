"""Register verified bestiary renders without replacing existing asset records."""
from pathlib import Path
import json,shutil
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'docs/production/media/bestiary'
forms=json.loads((ROOT/'우주-비즈니스/data/bestiary/forms.json').read_text())['forms']
verification=json.loads((base/'render-verification.json').read_text())
assert verification['status']=='pass' and verification['native_models']==len(forms)
p=ROOT/'우주-비즈니스/data/render_assets.json'
rows=json.loads(p.read_text());ids={r['id'] for r in rows}
records_path=ROOT/'docs/production/media/ink-catalog/renders.json'
metadata=json.loads(records_path.read_text());records={x['id']:x for x in metadata['assets']}
changed=set()
for row in forms:
 sample={'id':row['id'],'title':'LIFE ATLAS / '+row['family_name'],'name':row['name'],'group':'발견·환경','model':'res://'+row['lods']['near']['path'].removeprefix('우주-비즈니스/'),'source':row['source'],'geometry':'visual-prototype','foliage':row['category']!='animal','floor_y':row['geometry']['near']['floor_y'],'catalogue':'bestiary','review_status':'rendered; family contact sheets reviewed; final art approval pending'}
 if row['id'] not in ids:rows.append(sample)
 else:rows=[sample if r['id']==row['id'] else r for r in rows]
 source=base/'models'/f"{row['id']}.png";target=ROOT/'docs/production/media/ink-catalog'/f"{row['id']}.png"
 if not target.exists() or source.read_bytes()!=target.read_bytes():
  shutil.copyfile(source,target);changed.add(row['id'])
 records[row['id']]={'id':row['id'],'model':sample['model'],'geometry':sample['geometry'],'resolution':[1440,1200],'catalogue':'bestiary'}
metadata['assets']=list(records.values())
metadata['bestiary_review']='../bestiary/render-verification.json'
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
records_path.write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
print('REGISTERED_BESTIARY',len(forms),'TOTAL',len(rows))
# Keep the shared review board bounded to ten assets per page.
from PIL import Image
review=ROOT/'docs/production/media/ink-catalog'
environment=[r for r in rows if r['group']=='발견·환경']
for start in range(0,len(environment),10):
 page_rows=environment[start:start+10]
 suffix='' if start==0 else '-%03d'%(start//10+1)
 board_path=review/('board-environment'+suffix+'.png')
 if board_path.exists() and not any(r['id'] in changed for r in page_rows):continue
 board=Image.new('RGBA',(1440,((len(page_rows)+1)//2)*600),'#e5e2d6')
 for i,row in enumerate(page_rows):
  image=Image.open(review/(row['id']+'.png')).convert('RGBA').resize((720,600),Image.Resampling.LANCZOS)
  board.paste(image,((i%2)*720,(i//2)*600))
 suffix='' if start==0 else '-%03d'%(start//10+1)
 board.save(review/('board-environment'+suffix+'.png'))
print('PAGED_ENVIRONMENT_BOARDS',(len(environment)+9)//10)
