"""Author grip sockets and Blender hand assemblies for the four field tools.
Game tools export their sockets; the shared Blender glove rigs are instanced by Godot.
Run: Blender --background --python tools/build_field_tool_hands.py
"""
from pathlib import Path
import bpy, sys, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
OUT=ROOT/'docs/production/media/field-safety';OUT.mkdir(parents=True,exist_ok=True)
rows=json.loads((ROOT/'우주-비즈니스/data/render_assets.json').read_text())
def point(v):return Vector((v[0],-v[2],v[1]))
for row in rows:
 if row['id'] not in ['manual_tool','miner_mk2','terrain_shaper','terrain_mk2']:continue
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']))
 # Repeated runs replace only this script's review assembly and sockets.
 for obj in list(bpy.data.objects):
  if obj.get('field_hand_preview') or obj.name.startswith('Socket_Hand') or obj.type in ['CAMERA','LIGHT']:
   bpy.data.objects.remove(obj,do_unlink=True)
 miner=row['id'] in ['manual_tool','miner_mk2']
 contacts={'right':(.16,-.38,.28) if miner else (.13,-.32,.23), 'left':(-.13,-.30,-.25) if miner else (-.13,-.31,-.28)}
 for side,at in contacts.items():
  obj=bpy.data.objects.new('Socket_Hand'+side.capitalize(),None);bpy.context.collection.objects.link(obj)
  obj.location=point(at);obj.empty_display_type='ARROWS';obj.empty_display_size=.08
 tool_objects=list(bpy.context.scene.objects)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in tool_objects:obj.select_set(True)
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/row['source']))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'우주-비즈니스'/row['model'].removeprefix('res://')),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
 # Editable glove meshes, bones and grip are present in the Blender original.
 for side,at in contacts.items():
  before=set(bpy.data.objects)
  with bpy.data.libraries.load(str(ROOT/'art/blender/equipment'/('firearm_hand_'+side+'.blend')),link=False) as (src,dst):
   dst.objects=[name for name in src.objects if name.startswith('Survey')]
  added=[o for o in dst.objects if o]
  for obj in added:
   bpy.context.collection.objects.link(obj);obj['field_hand_preview']=True
  rig=next(o for o in added if o.type=='ARMATURE')
  rig.animation_data_clear()
  rig.location=point(at)-rig.data.bones['wrist'].head_local
  for obj in added:obj.hide_render=False
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/row['source']))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
 bpy.ops.object.camera_add(location=(2.3,2.8,1.7));camera=bpy.context.object
 camera.rotation_euler=(Vector((0,-.2,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.5;scene.camera=camera
 for location,energy in [((2,1,4),350),((-2,1,2),180)]:
  bpy.ops.object.light_add(type='AREA',location=location);bpy.context.object.data.energy=energy;bpy.context.object.data.size=3
 scene.world=bpy.data.worlds.new('Field gloves studio');scene.world.color=(.20,.20,.20)
 scene.render.resolution_x=900;scene.render.resolution_y=720;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(row['id']+'-blender.png'));bpy.ops.render.render(write_still=True)
 print('FIELD_HANDS',row['id'],contacts)
