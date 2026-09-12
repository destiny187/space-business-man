"""Blender source, glTF and rendered review for destructible field covers."""
from pathlib import Path
import sys, math, json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
OUT=ROOT/'docs/production/media/ground-combat';OUT.mkdir(parents=True,exist_ok=True)
for kind in ['combat_barrier','combat_barricade','combat_cover_kit']:
 k.reset();kit=kind=='combat_cover_kit';heavy=kind=='combat_barricade'
 if kit:
  k.box('Folded armor crate',(0,0,.26),(1.05,.7,.52),'dark',.09)
  for x in [-.39,.39]:k.box('Transport clamps',(x,0,.3),(.10,.78,.58),'orange',.025)
  k.box('Stacked panels',(0,0,.56),(.7,.6,.09),'cream',.025)
  k.pipe('Carry handle',[(-.2,0,.63),(-.2,0,.77),(.2,0,.77),(.2,0,.63)],.035,'steel')
 else:
  width=3.2 if heavy else 2.8;h=1.95 if heavy else 1.35;depth=.48 if heavy else .30
  for x in [-width*.42,width*.42]:
   k.box('Anchored foot',(x,0,.12),(.38,1.4 if heavy else 1.05,.24),'dark',.055)
   k.cyl('Foot hinge',(x,0,.24),.16,.30,'steel',(0,math.pi/2,0))
   for y in [-.40,.40]:k.cyl('Anchor bolt',(x,y,.23),.055,.035,'orange')
   k.box('Outer post',(x,0,h*.50),(.18,depth+.08,h*.92),'steel',.045)
  k.box('Lower rail',(0,0,.28),(width,.25,.18),'dark',.04)
  for i in [-1,0,1]:
   x=i*width*.31
   k.box('Armor panel',(x,0,h*.56),(width*.295,depth,h*.85),'cream',.065)
   k.box('Inset impact plate',(x,-depth*.53,h*.56),(width*.255,.06,h*.64),'teal',.04)
   for z in [h*.30,h*.80]:
    for dx in [-width*.105,width*.105]:k.cyl('Recessed fastener',(x+dx,-depth*.575,z),.035,.025,'steel',(math.pi/2,0,0))
   k.box('Warning chevron',(x,-depth*.59,h*.44),(width*.15,.04,.06),'orange',.008)
  k.box('Safe top rail',(0,0,h-.025),(width,.36 if not heavy else .54,.11),'dark',.04)
  if heavy:
   for x in [-.75,.75]:k.box('Rear reinforcing rib',(x,.28,.9),(.12,.12,1.55),'steel',.025)
 src=ROOT/'art/blender/equipment'/f'{kind}.blend';src.parent.mkdir(parents=True,exist_ok=True)
 model=('products/' if kit else '')+kind
 dest=ROOT/'우주-비즈니스/assets/models'/f'{model}.glb'
 bpy.ops.wm.save_as_mainfile(filepath=str(src));ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Cover studio');scene.world.color=(.18,.18,.18)
 bpy.ops.object.camera_add(location=(4.4,-6.8,4.2) if not kit else (2.2,-3.1,2.4));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.8 if not kit else .3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.9 if not kit else 2.0;scene.camera=cam
 for p,power,size in [((1,-3,6),700,5),((-4,-1,3),450,4),((0,4,5),600,3)]:
  bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=720;scene.render.resolution_y=540;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/(kind+'-blender.png'));bpy.ops.render.render(write_still=True)
 registry=ROOT/'우주-비즈니스/data/render_assets.json';data=json.loads(registry.read_text());data=[r for r in data if r['id']!=kind]
 data.append({'id':kind,'title':'전투 / 엄폐','name':kind,'group':'장비','model':'res://assets/models/'+model+'.glb','source':str(src.relative_to(ROOT)),'geometry':'ink-family-remodeled','foliage':False,'generator':'tools/build_combat_cover.py'})
 registry.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print('COVER_EXPORTED',kind)
