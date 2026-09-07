"""Tier-two manufactured products and distinct Mk.2 handhelds, Blender originals + GLB."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
exec(compile((R/'tools/build_vessel_modules.py').read_text().split('records=[]')[0],str(R/'tools/build_vessel_modules.py'),'exec'))
SRC=R/'art/blender/tier2';OUT=R/'우주-비즈니스/assets/models';MEDIA=R/'docs/production/media/tier2'
for p in [SRC,OUT/'products',MEDIA]:p.mkdir(parents=True,exist_ok=True)
products=json.loads((R/'우주-비즈니스/data/production_tier2.json').read_text())['products']
records=[]
def save(key,path,title):
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(key+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(path+'.glb')),export_format='GLB',export_yup=True)
 records.append({'id':key,'name':title,'source':str((SRC/(key+'.blend')).relative_to(R)),'model':'res://assets/models/'+path+'.glb','group':'2티어','geometry':'gameplay-prototype','foliage':False})
for key,recipe in products.items():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 if key.startswith('refined_'):
  for i in range(3):
   box('Cast ingot',(0,(i-1)*.24,.12),(.80,.20,.22),'steel' if key.endswith('iron') else 'orange',.055)
   box('Purity seal',(.12,(i-1)*.24,.239),(.25,.10,.014),'cream',.008)
 elif key=='reinforced_frame':
  for x in [-.36,.36]:box('Side rail',(x,0,.12),(.15,.85,.24),'steel',.035)
  for y in [-.35,.35]:box('Cross brace',(0,y,.12),(.68,.15,.24),'teal',.035)
  for x in [-.32,.32]:
   for y in [-.32,.32]:cylinder('Fastener',(x,y,.255),.048,.04,'orange',rot=(0,0,0),verts=16)
 elif key=='control_circuit':
  box('Shielded circuit board',(0,0,.06),(.70,.82,.12),'teal',.025)
  box('Processor',(0,.07,.17),(.27,.28,.14),'dark',.018)
  for x in [-.26,-.17,.17,.26]:
   box('Copper terminal',(x,-.37,.14),(.045,.14,.035),'orange',.006)
   box('Signal trace',(x,.02,.129),(.018,.45,.012),'cream',.003)
  for y in [.18,.30]:box('Capacitor',(-.23,y,.17),(.12,.08,.085),'steel',.012)
 elif key=='mineral_filter':
  for x in [-.19,.19]:
   cylinder('Filter core',(x,0,.23),.16,.70,'cream')
   for y in [-.35,.35]:cylinder('Cartridge collar',(x,y,.23),.18,.08,'teal')
   for y in [-.22,-.11,0,.11,.22]:cylinder('Filter pleat',(x,y,.23),.163,.03,'steel')
  box('Twin cartridge bridge',(0,0,.08),(.65,.18,.12),'dark',.025)
 elif key=='heat_transfer_unit':
  box('Heat manifold',(0,0,.10),(.70,.65,.20),'orange',.05)
  for x in [-.26,-.13,0,.13,.26]:box('Radiator fin',(x,0,.28),(.06,.6,.25),'steel',.018)
  for x in [-.23,.23]:cylinder('Coolant connector',(x,.40,.11),.065,.18,'teal')
 else:
  box('Substrate tray',(0,0,.10),(.8,.7,.20),'dark',.04)
  box('Compressed substrate',(0,0,.24),(.68,.58,.22),'orange',.06)
  for x in [-.25,.25]:box('Sealed strap',(x,0,.25),(.07,.72,.30),'cream',.02)
  box('Seed label',(0,-.30,.29),(.25,.03,.12),'teal',.02)
 save(key,'products/'+key,recipe['name'])
# physical retrofit pack used on facilities and robots
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
box('Quick release backplate',(0,0,.25),(.7,.24,.5),'dark',.05)
box('Upgrade enclosure',(0,.12,.27),(.60,.30,.42),'teal',.06)
for x in [-.2,.2]:
 cylinder('Replaceable cartridge',(x,.17,.28),.13,.45,'cream',rot=(0,0,0))
 box('Mk II bar',(x,.335,.30),(.06,.04,.25),'orange',.012)
for x in [-.31,.31]:box('Release latch',(x,.08,.25),(.10,.15,.19),'steel',.02)
save('retrofit_pack','products/retrofit_pack','Mk.2 개조 팩')
# Import authored originals so tool size/animation names stay intact.
for kind,base in [('miner','manual_tool'),('pulse','equipment/pulse_carbine'),('terrain','equipment/terrain_shaper')]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(OUT/(base+'.glb')))
 # compact sidecar and paired mechanical tier marks; different silhouette, same grip/muzzle
 box('Mk II capacitor housing',(.22,-.05,.10),(.17,.4,.23),'teal',.035)
 for y in [-.16,.02]:box('Mk II ceramic fin',(.30,y,.12),(.09,.10,.24),'cream',.02)
 for y in [-.15,-.04]:box('Mk II rank marker',(.355,y,.13),(.022,.045,.15),'orange',.006)
 save(kind+'_mk2','equipment/'+kind+'_mk2',{'miner':'자원채집기','pulse':'펄스 카빈','terrain':'지형 변환기'}[kind]+' Mk.2')
# Blender catalog render of products (actual geometry, no generated illustration).
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for i,key in enumerate(list(products)+['retrofit_pack']):
 old=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(OUT/('products/'+key+'.glb')))
 for o in set(bpy.data.objects)-old:
  if o.parent is None:o.location+=Vector(((i%4-1.5)*1.15,(i//4-.5)*1.25,0))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
bpy.ops.object.camera_add(location=(3,-5,6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.6;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-2,5));bpy.context.object.data.energy=650;bpy.context.object.data.size=5
scene.world.color=(.22,.22,.22);scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(MEDIA/'products-blender.png');bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'catalog.blend'));bpy.ops.render.render(write_still=True)
(SRC/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
p=R/'우주-비즈니스/data/render_assets.json';rows=json.loads(p.read_text());ids={r['id'] for r in records};rows=[r for r in rows if r['id'] not in ids]+records;p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
