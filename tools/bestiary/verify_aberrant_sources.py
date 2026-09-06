"""Inspect the editable Blender anatomy, independently of catalogue eye counts."""
from pathlib import Path
import bpy,json,collections
ROOT=Path(__file__).resolve().parents[2]
forms=[r for r in json.loads((ROOT/'우주-비즈니스/data/bestiary/forms.json').read_text())['forms'] if r.get('collection')=='aberrant']
assert len(forms)==100
records=[]
for i,row in enumerate(forms):
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']))
 names=[o.name for o in bpy.context.scene.objects]
 assert 'Anim_Body' in names and not any(n.startswith('Protected orbit') or n.startswith('Lens pupil') or n=='Anim_Head' for n in names),row['id']
 prefixes={'eye_orchard':'Needle pupil','asym_pincer':'Single dark sclera','ribbon_colony':'Dermal photoreceptor','window_sac':'Single vertical photoreceptor','crown_stalker':'Faceted crown substrate','manymouth':'Dermal photoreceptor'}
 prefix=prefixes.get(row['family'])
 eyes=sum(n.startswith(prefix) for n in names) if prefix else 0
 assert eyes==row['eye_count'],(row['id'],eyes,row['eye_count'])
 assert sum(o.type=='MESH' for o in bpy.context.scene.objects)>0
 records.append({'id':row['id'],'source_eye_organs':eyes,'compound_lens_facets':sum(n.startswith('Compound lens facet') for n in names)})
 if i%10==0:print('ABERRANT_SOURCE_CHECK',i+1,flush=True)
result={'status':'pass','sources_checked':len(records),'scope':'Saved Blender source objects: explicit anatomical eye organs and absence of reused paired-eye head. Compound lens facets are not separate eyes.','models':records}
(ROOT/'docs/production/media/bestiary/aberrant/source-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('ABERRANT_SOURCE_VERIFIED',len(records),flush=True)
