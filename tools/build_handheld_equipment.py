"""Distinct INK handhelds. Blender +Y is Godot -Z; originals keep movable parts."""
from pathlib import Path
import bpy, math, json
R=Path(__file__).resolve().parents[1]
# Reuse only the established modeling helpers, without executing its asset generation.
source=(R/'tools/build_vessel_modules.py').read_text().split('records=[]')[0]
exec(compile(source,str(R/'tools/build_vessel_modules.py'),'exec'))
SOURCE=R/'art/blender/equipment';OUTPUT=R/'우주-비즈니스/assets/models/equipment'
SOURCE.mkdir(exist_ok=True,parents=True);OUTPUT.mkdir(exist_ok=True,parents=True)
records=[]
for kind in ['pulse_carbine','terrain_shaper']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 box('Ergonomic grip',(0,-.13,-.19),(.16,.19,.38),'dark',.045)
 box('Grip heel',(0,-.14,-.36),(.20,.22,.08),'orange',.025)
 box('Power receiver',(0,-.06,.04),(.32,.56,.25),'teal',.06)
 box('Upper ceramic armor',(0,-.10,.20),(.34,.46,.12),'cream',.04)
 box('Trigger guard',(0,.04,-.13),(.23,.27,.07),'steel',.025)
 for x in [-.18,.18]:
  cylinder('Receiver bolt',(x,-.18,.07),.04,.025,'steel',rot=(0,math.pi/2,0),verts=12)
 if kind=='pulse_carbine':
  box('Shoulder stabilizer',(0,-.55,.08),(.26,.48,.17),'dark',.05)
  box('Stock pad',(0,-.79,.07),(.31,.10,.25),'cream',.035)
  cylinder('Accelerator housing',(0,.30,.07),.135,.70,'dark')
  for y in [.12,.31,.50]:
   cylinder('Induction ring',(0,y,.07),.17,.085,'teal')
   for x in [-.15,.15]:box('Emitter cooling rail',(x,.31,.11),(.05,.51,.10),'steel',.012)
  cylinder('Anim_Piston_Muzzle',(0,.72,.07),.145,.18,'cream')
  cylinder('Muzzle recess',(0,.82,.07),.106,.025,'dark')
  cylinder('Pulse emitter',(0,.84,.07),.053,.015,'light')
  box('Magazine',(0,-.04,-.31),(.19,.26,.33),'cream',.03)
  box('Magazine latch',(.11,-.02,-.19),(.04,.11,.10),'orange',.01)
  box('Reflex sight foot',(0,-.06,.29),(.14,.20,.06),'dark',.02)
  for x in [-.066,.066]:box('Sight upright',(x,-.05,.36),(.025,.06,.13),'steel',.01)
  box('Sight bridge',(0,-.05,.43),(.16,.06,.03),'orange',.01)
 else:
  cylinder('Field chamber',(0,.22,.06),.24,.44,'cream')
  cylinder('Field chamber rear',(0,-.02,.06),.255,.06,'teal')
  cylinder('Containment collar',(0,.48,.06),.27,.10,'dark')
  cylinder('Anim_Collar_Field',(0,.56,.06),.245,.075,'orange')
  cylinder('Field aperture',(0,.61,.06),.19,.025,'dark')
  cylinder('Field core',(0,.64,.06),.11,.025,'light')
  for x in [-.28,.28]:
   box('Fork root',(x,.43,.06),(.13,.23,.24),'teal',.04)
   box('Field projection fork',(x,.67,.06),(.09,.42,.15),'cream',.025)
   box('Fork terminal',(x,.87,.06),(.10,.07,.16),'steel',.015)
   box('Field guide',(x*.79,.76,.06),(.045,.22,.09),'light',.01)
  for y in [.06,.17,.28]:box('Cooling fin',(0,y,.31),(.31,.045,.10),'steel',.012)
  box('Pressure cartridge',(0,-.31,.04),(.30,.12,.22),'orange',.035)
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(kind+'.glb')),export_format='GLB',export_yup=True)
 # Render Blender original for geometry inspection; Godot INK captures are separate.
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
 bpy.ops.object.camera_add(location=(1.6,2,1.1));cam=bpy.context.object
 from mathutils import Vector
 cam.rotation_euler=(Vector((0,0,.05))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.0;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(1,1,3));bpy.context.object.data.energy=220;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=3
 scene.world.color=(.22,.22,.22);scene.render.resolution_x=720;scene.render.resolution_y=600;scene.render.resolution_percentage=100
 dest=R/'docs/production/media/equipment';dest.mkdir(exist_ok=True,parents=True)
 scene.render.filepath=str(dest/(kind+'-blender.png'));bpy.ops.render.render(write_still=True)
 records.append({'id':kind,'source':str((SOURCE/(kind+'.blend')).relative_to(R)),'model':str((OUTPUT/(kind+'.glb')).relative_to(R)),'generator':'tools/build_handheld_equipment.py','style':'ink-v1','status':'gameplay prototype'})
(SOURCE/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
p=R/'우주-비즈니스/data/render_assets.json';rows=json.loads(p.read_text())
for row in records:
 rows=[r for r in rows if r['id']!=row['id']]
 rows.append({'id':row['id'],'title':'휴대 장비','name':{'pulse_carbine':'펄스 카빈','terrain_shaper':'지형 변환기'}[row['id']],'group':'장비','model':'res://assets/models/equipment/'+row['id']+'.glb','source':row['source'],'geometry':'visual-prototype','foliage':False})
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
