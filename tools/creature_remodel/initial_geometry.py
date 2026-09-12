"""Read the nine existing approved Blender sources using the production geometry digest.

Run with Blender --background --python tools/creature_remodel/initial_geometry.py.
No source or exported asset is modified.
"""
from pathlib import Path
import bpy,json,numpy as np,hashlib
root=Path(__file__).resolve().parents[2];rows=json.loads((root/'우주-비즈니스/data/creature_remodel_r01.json').read_text())['forms'];records=[]
for row in rows:
 bpy.ops.wm.open_mainfile(filepath=str(root/row['source']))
 points=np.array([tuple(ob.matrix_world@v.co) for ob in bpy.context.scene.objects if ob.type=='MESH' for v in ob.data.vertices]);points=(points-points.min(axis=0))/max(np.ptp(points,axis=0))
 arm=next(ob for ob in bpy.context.scene.objects if ob.type=='ARMATURE');graph={b.name:b.parent.name if b.parent else None for b in arm.data.bones}
 records.append({'id':row['id'],'source_id':row['source_id'],'source_sha256':hashlib.sha256((root/row['source']).read_bytes()).hexdigest(),'normalized_geometry_sha256':hashlib.sha256(np.round(points,5).tobytes()).hexdigest(),'skeleton_topology':graph})
 print('R01_EXISTING_GEOMETRY',row['id'],flush=True)
path=root/'output/creature-remodel/r01/final-geometry.json';path.parent.mkdir(exist_ok=True);path.write_text(json.dumps(records,indent=2)+'\n')
