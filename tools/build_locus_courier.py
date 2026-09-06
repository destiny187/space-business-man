"""Articulated transport variant of the approved M-07; preserves the reference."""
from pathlib import Path
import bpy, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/blender/showcase/locus_m07.blend'
out=ROOT/'art/blender/robots';out.mkdir(parents=True,exist_ok=True)
game=ROOT/'우주-비즈니스/assets/models/robots';game.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
wheel_names=('Continuous rounded tire','Wheel barrel','Wheel enamel rim','Hub recess','Hub cap','Recessed wheel fastener','Tire traction block')
pivots={}
for side in [-1,1]:
 for index,y in enumerate([-.97,.06,1.03]):
  pivot=bpy.data.objects.new(f'Anim_Wheel_{"L" if side<0 else "R"}_{index}',None)
  bpy.context.collection.objects.link(pivot);pivot.location=(side*.91*1.58,y,.63)
  pivots[(side,index)]=pivot
bpy.context.view_layer.update()
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH' or not obj.name.startswith(wheel_names):continue
 side=-1 if obj.location.x<0 else 1
 index=min(range(3),key=lambda i:abs(obj.location.y-[-.97,.06,1.03][i]))
 # Tread/fastener offsets around a wheel can overlap neighbours; reference
 # creation order groups each complete wheel, so use nearest wheel centre
 # after parent assignment only for meshes whose origin belongs to that wheel.
 if obj.name.startswith(('Tire traction block','Recessed wheel fastener')):
  number=int(obj.name.rsplit('.',1)[1]) if '.' in obj.name and obj.name.rsplit('.',1)[1].isdigit() else 0
  group=number//(32 if obj.name.startswith('Tire traction block') else 6)
  side=-1 if group<3 else 1;index=group%3
 pivot=pivots[(side,index)];matrix=obj.matrix_world.copy();obj.parent=pivot;obj.matrix_world=matrix
bpy.ops.wm.save_as_mainfile(filepath=str(out/'locus_courier.blend'))
groups={}
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH':continue
 bpy.context.view_layer.objects.active=obj
 for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
 groups.setdefault((obj.parent.name if obj.parent else '',obj.data.materials[0].name),[]).append(obj)
for group in groups.values():
 bpy.ops.object.select_all(action='DESELECT')
 for obj in group:obj.select_set(True)
 bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=str(game/'locus_courier.glb'),export_format='GLB',export_yup=True)
triangles=0
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
(out/'locus_courier.json').write_text(json.dumps({'source_reference':str(source.relative_to(ROOT)),'source':'art/blender/robots/locus_courier.blend','output':'우주-비즈니스/assets/models/robots/locus_courier.glb','triangles':triangles,'wheel_pivots':6,'surfaces':len(groups),'geometry':'approved reference with articulated wheel export; no new final approval'},indent=2))
print('COURIER_EXPORT',triangles,len(groups))
