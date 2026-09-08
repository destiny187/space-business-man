"""Rebuild the legacy storage at the same footprint using shared INK industrial roles.
Blender source retains parts. Static GLB surfaces are consolidated for the game.
"""
from pathlib import Path
import bpy, sys, json, math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
OUT=ROOT/'art/blender';GAME=ROOT/'우주-비즈니스/assets/models'
REVIEW=ROOT/'docs/production/media/ink-family';REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
p={k:ink.material(v) for k,v in {'cream':'enamel_cream','teal':'enamel_teal','orange':'safety_orange','dark':'structural_dark','steel':'edge_steel'}.items()}
def box(name,loc,size,role,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(p[role]);ink.manufactured_edges(o,bevel);return o
def cylinder(name,loc,r,depth,role,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=loc,rotation=rot);o=bpy.context.object;o.name=name;o.data.materials.append(p[role]);ink.manufactured_edges(o,min(.018,depth*.2));return o
# Original foundation 3.6 m square, door/front on Blender -Y / Godot +Z.
box('Load bearing plinth',(0,0,.13),(3.6,3.6,.26),'dark',.09)
box('Recessed loading apron',(0,0,.29),(3.42,3.42,.12),'steel',.04)
for x in [-1.58,1.58]:
 for y in [-1.58,1.58]:
  cylinder('Foundation anchor',(x,y,.36),.10,.08,'orange')
# Three reinforced bays with actual recessed faces, individual seals and service latches.
box('Rounded cargo shell',(0,0,1.10),(2.8,2.8,1.50),'cream',.14)
box('Roof gasket',(0,0,1.83),(2.86,2.86,.08),'dark',.04)
box('Stackable roof',(0,0,1.91),(2.96,2.94,.14),'teal',.08)
for x in [-1.27,1.27]:
 box('Corner armour',(x,-1.405,1.07),(.20,.12,1.33),'cream',.04)
 box('Stacking runner',(x,0,1.99),(.17,2.42,.07),'steel',.025)
for x in [-.86,0,.86]:
 box('Door seal',(x,-1.416,1.10),(.82,.075,1.27),'dark',.055)
 box('Cargo bay face',(x,-1.46,1.10),(.73,.08,1.14),'teal',.065)
 box('Recessed label panel',(x,-1.507,1.40),(.43,.018,.15),'dark',.02)
 box('Identification inset',(x,-1.52,1.40),(.20,.018,.05),'cream',.008)
 box('Latch base',(x+.22,-1.515,1.08),(.12,.035,.23),'dark',.025)
 box('Safety pull handle',(x+.22,-1.55,1.08),(.075,.05,.15),'orange',.025)
 for z in [.70,1.02]:
  box('Exposed hinge',(x-.32,-1.516,z),(.10,.08,.13),'steel',.018)
 box('Door kick plate',(x,-1.508,.68),(.50,.025,.10),'steel',.015)
# Readable large side assemblies, not micro-embossed text or ornamental bolts.
for x in [-1.415,1.415]:
 box('Recessed service panel',(x,.06,1.11),(.06,1.65,.92),'dark',.045)
 box('Side protective shield',(x*1.02,-.35,1.11),(.06,.65,.77),'teal',.04)
 for z in [.91,1.09,1.27]:box('Cooling louvre',(x*1.03,.45,z),(.05,.68,.075),'steel',.015)
 for y in [-1.05,1.05]:box('Side load rib',(x,y,1.1),(.12,.14,1.22),'cream',.035)
# Recessed dark fork guides with orange wear rails identify the loading edge.
for x in [-.80,.80]:
 box('Fork pocket surround',(x,-1.53,.44),(.56,.24,.20),'dark',.028)
 for xx in [x-.24,x+.24]:box('Pocket protection',(xx,-1.66,.45),(.065,.05,.22),'orange',.015)
for x in [-.7,.7]:
 box('Rear reinforcement',(x,1.415,1.1),(.16,.08,1.20),'steel',.03)
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'storage.blend'))
editable=sum(o.type=='MESH' for o in bpy.context.scene.objects)
exported=ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(GAME/'storage.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
manifest=OUT/'manifest.json';records=json.loads(manifest.read_text())
for record in records:
 if record['id']=='storage':record.update(generator='tools/build_locus_storage.py',material_preset=ink.PRESET['version'],editable_objects=editable,export_objects=exported,blender=bpy.app.version_string,geometry='ink-family-remodeled')
manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Review world');scene.world.color=(.16,.16,.16)
box('Review floor',(0,0,-.05),(200,200,.08),'cream')
bpy.ops.object.camera_add(location=(6,-8,5));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.4;scene.camera=cam
for pos,energy in [((3,-5,7),1600),((-4,-1,5),900)]:
 bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=5;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/'storage-blender.png');bpy.ops.render.render(write_still=True)
print('INK_STORAGE_EXPORTED',editable,exported)
