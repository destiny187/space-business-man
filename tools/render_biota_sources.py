"""Resume missing/current Blender representative images without rewriting assets.
Run after the authoring workers finish. Every group retains five source views.
"""
import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector
import build_biota as author

rendered=0;ready=0;missing=[]
for spec in author.recipes():
    if spec['anatomy'] not in [0,5,8,24,49]:continue
    path=author.X.SRC/(spec['id']+'.json')
    if not author.current_checkpoint(path):missing.append(spec['id']);continue
    row=json.loads(path.read_text());source=author.ROOT/row['source']
    destination=author.X.REVIEW/'blender'/(row['id']+'.png')
    if destination.exists() and destination.stat().st_mtime_ns>=source.stat().st_mtime_ns:ready+=1;continue
    bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box]
    author.X.source_render(row,points);rendered+=1;ready+=1
    print('BIOTA_SOURCE_RENDERED',row['id'],flush=True)
print('BIOTA_SOURCE_REVIEW',ready,'/700','rendered',rendered,'missing_assets',missing,flush=True)
if missing:raise RuntimeError('Source representatives still await complete models')
