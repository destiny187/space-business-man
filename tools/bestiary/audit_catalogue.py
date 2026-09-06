from pathlib import Path
import sys,json,collections,hashlib,time
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from verify_geometry import geometry
p=ROOT/'우주-비즈니스/data/bestiary/forms.json'
data=json.loads(p.read_text());appearances=json.loads((p.parent/'appearances.json').read_text())['appearances']
assert len(data['forms'])==600
assert len(appearances)==12000
ids={};shape_ids=collections.defaultdict(list);report=[];start=time.time()
for i,row in enumerate(data['forms']):
 assert row['id'] not in ids;ids[row['id']]=row
 assert (ROOT/row['source']).exists()
 for lod in ['near','far']:
  path=ROOT/row['lods'][lod]['path']
  assert hashlib.sha256(path.read_bytes()).hexdigest()==row['lods'][lod]['sha256'],path
  info=geometry(path);row.setdefault('geometry',{})[lod]=info
  assert info['vertices']>0 and all(abs(x)<100 for x in info['min']+info['max'])
 shape_ids[row['geometry']['near']['geometry_hash']].append(row['id'])
 report.append({'id':row['id'],'floor_near':row['geometry']['near']['floor_y'],'near_triangles':row['lods']['near']['triangles'],'far_triangles':row['lods']['far']['triangles']})
 if i%50==0:print('GEOMETRY_AUDIT',i+1,flush=True)
look_ids=set()
for look in appearances:
 assert look['id'] not in look_ids
 look_ids.add(look['id'])
 form=ids[look['form_id']]
 assert look['environment']==form['environment']
 assert .8<=look['scale']<=1.2 and not look['spawn_enabled']
 assert len(look['palette'])==3 and all(len(x)==6 for x in look['palette'])
for row in data['forms']:
 assert sum(x['form_id']==row['id'] for x in appearances)==20
duplicates=[v for v in shape_ids.values() if len(v)>1]
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
out=ROOT/'docs/production/media/bestiary'
out.mkdir(parents=True,exist_ok=True)
result={'forms':len(ids),'unique_geometry':len(shape_ids),'duplicate_geometry':duplicates,'appearances':len(look_ids),'categories':dict(collections.Counter(x['category'] for x in data['forms'])),'attacking_forms':sum(x['attack']!='none' for x in data['forms']),'structural_families':len(set(x['family'] for x in data['forms'])),'seconds':round(time.time()-start,2),'models':report,'status':'pass' if not duplicates else 'failed'}
(out/'geometry-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='models'},ensure_ascii=False),flush=True)
assert not duplicates,'Color-only duplicates cannot count as different base models'
