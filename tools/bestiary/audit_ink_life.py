"""Audit changed exports; retain original source identity for reviewed untouched forms."""
from pathlib import Path
import json,hashlib,sys
sys.path.insert(0,str(Path(__file__).parent))
from verify_geometry import geometry
ROOT=Path(__file__).resolve().parents[2];DEST=ROOT/'docs/production/media/ink-life'
selected=set(json.loads((DEST/'selection.json').read_text())['rebuild'])
cache=DEST/'geometry-records';cache.mkdir(exist_ok=True)
for id in sorted(selected):
 record=DEST/'records'/(id+'.json')
 if not record.exists():continue
 row=json.loads(record.read_text());path=cache/(id+'.json')
 previous=json.loads(path.read_text()) if path.exists() else {}
 if previous.get('lods')==row['lods']:continue
 info={lod:geometry(ROOT/v['path']) for lod,v in row['lods'].items()}
 path.write_text(json.dumps({'id':id,'lods':row['lods'],'geometry':info},indent=2)+'\n');print('INK_GEOMETRY',id,flush=True)
if '--finalize' not in sys.argv:raise SystemExit()
path=ROOT/'우주-비즈니스/data/bestiary/forms.json';data=json.loads(path.read_text());base=json.loads((DEST/'baseline.json').read_text());rows=[];shapes={};verified=[]
for original in base['forms']:
 id=original['id'];changed=id in selected
 if changed:
  row=json.loads((DEST/'records'/(id+'.json')).read_text());audit=json.loads((cache/(id+'.json')).read_text());assert audit['lods']==row['lods'];row['geometry']=audit['geometry']
  assert set(row['pivots'])==set(row['motion_contract']),id
  for key in ['id','family','category','environment','attack','palette','eye_design','eye_count','sensory_type']:
   assert original.get(key)==row.get(key),(id,key)
 else:row=original
 for lod,v in row['lods'].items():assert hashlib.sha256((ROOT/v['path']).read_bytes()).hexdigest()==v['sha256'],(id,lod)
 shapes.setdefault(row['geometry']['near']['geometry_hash'],[]).append(id)
 if changed:
  for target in [DEST/'records'/(id+'.json'),ROOT/Path(row['source']).with_suffix('.json')]:target.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
 rows.append(row);verified.append({'id':id,'decision':'remodeled' if changed else 'retained','near_sha256':row['lods']['near']['sha256'],'far_sha256':row['lods']['far']['sha256']})
assert len(shapes)==600,[v for v in shapes.values() if len(v)>1]
data['forms']=rows;path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
report={'reviewed':len(rows),'remodeled':len(selected),'retained':len(rows)-len(selected),'unique_shapes':len(shapes),'status':'pass','forms':verified}
(DEST/'asset-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('INK_ASSETS_VERIFIED',len(rows),len(selected),flush=True)
