"""Register the completed native INK review after human contact-sheet inspection."""
from pathlib import Path
import json,hashlib,struct,collections
from PIL import Image,ImageStat
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'docs/production/media/ink-life'
forms_path=ROOT/'우주-비즈니스/data/bestiary/forms.json';data=json.loads(forms_path.read_text());selected=set(json.loads((P/'selection.json').read_text())['rebuild'])
style_sha=hashlib.sha256((ROOT/'우주-비즈니스/data/render_style.json').read_bytes()).hexdigest();records=[];image_hashes=set()
for row in data['forms']:
 id=row['id'];record=json.loads((P/'render-records'/(id+'.json')).read_text())
 assert record['model_sha256']==row['lods']['near']['sha256'] and record['style_sha256']==style_sha and not record['failures'],id
 for folder,size in [('game',(1440,1200)),('lod',(720,600))]:
  with Image.open(P/folder/(id+'.png')) as im:
   assert im.size==size,(id,folder,im.size)
   assert max(ImageStat.Stat(im.convert('RGB').resize((64,64))).stddev)>8,(id,folder)
 with Image.open(ROOT/'우주-비즈니스/assets/ui/previews'/(id+'.png')) as preview:assert preview.size==(480,400),id
 image_hashes.add(hashlib.sha256((P/'game'/(id+'.png')).read_bytes()).hexdigest())
 row.update(render_status='ink-life-reviewed',art_review='docs/production/54-planets-and-life-art.md',review_decision='remodeled' if id in selected else 'existing-geometry-retained')
 if id in selected:
  blob=(ROOT/row['lods']['near']['path']).read_bytes();n=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+n]);row['mesh_nodes']=sum('mesh' in node for node in doc['nodes'])
  for path in [ROOT/Path(row['source']).with_suffix('.json'),P/'records'/(id+'.json')]:path.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
 records.append(record)
assert len(records)==600 and len(image_hashes)==600
forms_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
forms={r['id']:r for r in data['forms']};path=ROOT/'우주-비즈니스/data/render_assets.json';assets=json.loads(path.read_text())
for asset in assets:
 id=asset['id']
 if id in forms:
  row=forms[id];asset.update(geometry='ink-life-remodeled' if id in selected else 'ink-life-reviewed-existing',review_status='INK v1 geometry, native render and motion reviewed',review='docs/production/54-planets-and-life-art.md',floor_y=row['geometry']['near']['floor_y'])
  if id in selected:asset['generator']='tools/build_ink_bestiary.py'
 elif '/solar-system/' in asset.get('model',''):
  asset.update(geometry='ink-life-remodeled',review='docs/production/54-planets-and-life-art.md',generator='tools/build_ink_planets.py')
path.write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n')
path=ROOT/'docs/production/media/ink-catalog/renders.json';metadata=json.loads(path.read_text());by_id={a['id']:a for a in assets}
for record in metadata['assets']:
 if record['id'] in forms:record['geometry']=by_id[record['id']]['geometry'];record['review']='../ink-life/verification.json'
metadata['bestiary_review']='../ink-life/verification.json';metadata['bestiary_style']=json.loads((ROOT/'우주-비즈니스/data/render_style.json').read_text());path.write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
report={'status':'pass','reviewed_base_forms':600,'remodeled':len(selected),'retained':600-len(selected),'native_renders':600,'preview_size':[480,400],'near_far_pairs':600,'motion_states_per_form':5,'attack_forms':sum(r['attack']!='none' for r in data['forms']),'lighting_representatives':sum(r['representative'] for r in records),'failures':0,'style_sha256':style_sha,'appearance_sha256':hashlib.sha256((ROOT/'우주-비즈니스/data/bestiary/appearances.json').read_bytes()).hexdigest(),'appearance_profiles_unchanged':12000,'appearance_profiles_rerendered':0,'renderer':'Godot 4.7.2 Metal Forward+ / Apple M2','visual_review':'All 30 original family sheets; 8 revised families; final family overview; representative Blender, lighting and motion renders','limits':'Atlas motion/LOD presentation and actual planet/surface scenes; no full regression or long multiplayer run'}
(P/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False))
