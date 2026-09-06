"""Blender source check: eye edits preserve the body and motion anchor geometry."""
from pathlib import Path
import bpy,json,sys,hashlib
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from eye_designs import EYE_DESIGNS
EYE_PARTS=['Protected orbit','Sensory lens','Lens pupil','Vibration receptor fold','Central dark orbit','Diamond iris','Diamond pupil','Cluster orbit','Small cluster lens','Compound ocular shield','Compound lens cell','Elongated orbit','Shaped iris','Aperture pupil','Protective brow','Stacked orbit','Stacked lens','Stacked pupil']
def body_signature(path):
 bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();result={}
 for o in bpy.context.scene.objects:
  if any(o.name.startswith(prefix) for prefix in EYE_PARTS):continue
  if o.type not in ['MESH','EMPTY']:continue
  result[o.name]=([round(v,5) for row in o.matrix_world for v in row], [tuple(round(x,5) for x in v.co) for v in o.data.vertices] if o.type=='MESH' else [])
 return result
rows=[]
for id,design in EYE_DESIGNS.items():
 path=ROOT/'art/blender/bestiary'/f'{id}.blend'
 before=body_signature(Path(str(path)+'1'));after=body_signature(path)
 assert before==after,(id,'Non-eye geometry or motion anchors changed')
 names=[o.name for o in bpy.context.scene.objects]
 assert not any(n.startswith('Protected orbit') for n in names),id
 rows.append({'id':id,'eye_design':design[0],'eye_count':design[1],'unchanged_body_objects':len(after)})
report={'status':'pass','edited_models':len(rows),'scope':'Source objects excluding the explicitly named old/new eye parts: transforms and mesh vertices unchanged, including motion anchors.','models':rows}
(ROOT/'docs/production/media/bestiary/eye-revision/source-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('EYE_REVISION_SOURCE_CHECK',len(rows),'passed',flush=True)
