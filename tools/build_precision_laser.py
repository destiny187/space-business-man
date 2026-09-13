"""Dedicated laser optics, side-loading cell and moving cooling louvers. Blender INK v1."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
# Reuse authored firearm construction helpers without running its export loop.
scope={'__file__':str(ROOT/'tools/build_firearms.py')}
exec((ROOT/'tools/build_firearms.py').read_text().split('for family,spec in families.items():')[0],scope)
k=scope['k'];ink=scope['ink'];box=scope['box'];barrel=scope['barrel'];pivot=scope['pivot']
k.reset()
box('Optical bench',(0,.15,.06),(.21,.93,.19),'dark',.035)
box('Rear electronics',(0,-.28,.06),(.25,.27,.24),'teal',.045)
g=box('Swept insulated grip',(0,-.23,-.24),(.12,.16,.29),'dark',.033);g.rotation_euler.x=-.2
k.pipe('Trigger guard',[(-.045,-.19,-.1),(-.045,-.07,-.1),(-.045,-.07,-.24),(-.045,-.19,-.24)],.014,'steel')
box('Interlock trigger',(0,-.12,-.16),(.025,.035,.085),'orange',.008)
box('Shoulder spine',(0,-.54,.02),(.10,.38,.11),'steel')
box('Cheek cushion',(0,-.51,.15),(.17,.22,.08),'cream')
box('Butt pad',(0,-.73,.01),(.20,.10,.27),'dark',.04)
for y,r in [(.02,.17),(.22,.145),(.42,.12)]:
 barrel('Optical focusing housing',(0,y,.12),r,.14,'cream')
 barrel('Lens mounting collar',(0,y+.076,.12),r*1.04,.018,'orange')
 barrel('Protected optical glass',(0,y+.089,.12),r*.75,.009,'status')
 for x in [-.17,.17]:box('Bench brace',(x,y,.04),(.045,.15,.055),'steel',.012)
for x in [-.18,.18]:box('Protective guide rail',(x,.26,.20),(.045,.69,.05),'teal',.012)
barrel('Collimator',(0,.60,.12),.085,.20,'dark');barrel('Faceted emitter rim',(0,.71,.12),.1,.04,'cream');barrel('Emitter glass',(0,.738,.12),.059,.014,'status')
pivot('Socket_Muzzle',(0,.75,.12))
cell=pivot('Anim_Magazine',(-.18,.10,.02))
box('Removable side battery',(-.235,.10,.02),(.15,.29,.17),'teal',.028,cell)
box('Battery grasp ridge',(-.32,.10,.02),(.04,.24,.13),'cream',.012,cell)
for y in [.01,.07,.13,.19]:box('Cell charge indicator',(-.345,y,.02),(.014,.025,.073),'status',.004,cell)
bolt=pivot('Anim_Bolt',(-.18,.16,.08));box('Cell clamp',(-.18,.16,.095),(.13,.045,.035),'orange',.008,bolt)
for i in range(7):
 y=-.15+i*.055
 louver=pivot('Anim_Heat_'+str(i),(.145,y,.11))
 box('Articulated radiator',(.185,y,.12),(.115,.022,.16),'steel',.008,louver)
box('Reflex sight pedestal',(0,-.23,.245),(.10,.17,.065),'dark')
for x in [-.065,.065]:box('Sight guard',(x,-.23,.32),(.025,.05,.11),'cream',.006)
box('Reticle emitter',(0,-.23,.365),(.14,.05,.025),'orange',.006)
scene=bpy.context.scene;scene.unit_settings.system='METRIC';source=ROOT/'art/blender/equipment/gun_laser.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(ROOT/'우주-비즈니스/assets/models/equipment/gun_laser.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
scene.world=bpy.data.worlds.new('Optics studio');scene.world.color=(.18,.18,.18)
bpy.ops.object.camera_add(location=(-1.5,1.8,1.1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.0;scene.camera=cam
for pos,power in [((1,1,3),240),((-1,0,2),180)]:
 bpy.ops.object.light_add(type='AREA',location=pos);bpy.context.object.data.energy=power;bpy.context.object.data.size=3
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1000;scene.render.resolution_y=750;scene.render.resolution_percentage=100
out=ROOT/'docs/production/media/firearm-precision';out.mkdir(exist_ok=True,parents=True);scene.render.filepath=str(out/'laser-blender.png');bpy.ops.render.render(write_still=True)
p=ROOT/'우주-비즈니스/data/render_assets.json';rows=json.loads(p.read_text());rows=[r for r in rows if r['id']!='gun_laser'];rows.append({'id':'gun_laser','title':'프리즘 레이저','name':'프리즘 레이저','group':'장비','model':'res://assets/models/equipment/gun_laser.glb','source':str(source.relative_to(ROOT)),'geometry':'ink-family-remodeled','foliage':False,'view_direction':[-1.22,.84,-1.7]});p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')

manifest=ROOT/'art/blender/equipment/firearms.json'
records=json.loads(manifest.read_text()) if manifest.exists() else []
records=[r for r in records if r['id']!='gun_laser']
records.append({'id':'gun_laser','name':'프리즘 레이저','source':str(source.relative_to(ROOT)),'model':'res://assets/models/equipment/gun_laser.glb','motion':['Anim_Magazine','Anim_Bolt']+['Anim_Heat_'+str(i) for i in range(7)],'generator':'tools/build_precision_laser.py','style':'INK v1','view_direction':[-1.22,.84,-1.7]})
manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
