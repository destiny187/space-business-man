"""T3 source-control skid and distinct retrofit modules, using the shared INK tooling."""
from pathlib import Path
import sys,json,math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as kit
import ink_blender as ink
OUT=ROOT/'art/blender/terraform3';GAME=ROOT/'우주-비즈니스/assets/models/terraform3';REVIEW=ROOT/'docs/production/media/terraform3'
for p in [OUT,GAME,REVIEW]:p.mkdir(parents=True,exist_ok=True)

def tank(x,y,z,radius,height):
 kit.cyl('Pressure shell',(x,y,z),radius,height,'cream')
 for h in [-height*.38,height*.38]:kit.ring('Dark vessel band',(x,y,z+h),radius+.01,.045,'dark')
 kit.cyl('Service lid',(x,y,z+height*.5+.035),radius*.95,.12,'teal')
 kit.box('Front replaceable cassette',(x,y-radius-.04,z),(.28,.14,height*.55),'teal',.04)
 kit.box('Latch',(x,y-radius-.14,z),(.16,.07,.12),'orange',.025)

def base(w,d):
 kit.box('Skid frame',(0,0,.15),(w,d,.3),'dark',.06)
 kit.box('Enamel platform',(0,0,.34),(w-.12,d-.12,.15),'teal',.04)
 for x in [-w*.38,w*.38]:
  for y in [-d*.36,d*.36]:kit.box('Vibration isolator',(x,y,.10),(.26,.3,.2),'rubber',.04)

def source():
 base(3.6,3.1)
 for x in [-.78,.78]:tank(x,.2,1.8,.58,2.5)
 kit.pipe('Source capture manifold',[(-.78,.2,2.95),(-.78,.2,3.32),(.78,.2,3.32),(.78,.2,2.95)],.12,'steel')
 kit.pipe('Ground inlet',[(0,1.2,.18),(0,1.2,.65),(-.78,1.0,.75),(-.78,.7,1.05)],.15,'dark')
 kit.box('Control console',(0,-1.05,1.15),(.75,.35,.85),'cream',.10)
 kit.box('Control screen',(0,-1.25,1.35),(.48,.03,.32),'dark',.02)
 for x in [-.12,0,.12]:kit.box('Operating state',(x,-1.28,1.38),(.055,.04,.15),'status',.01)
 rotor=kit.pivot('Anim_Agitator_Source',(0,-1.07,.58))
 kit.cyl('Circulation rotor',(0,-1.07,.58),.28,.20,'orange',parent=rotor)
 for a in range(4):
  theta=a*math.pi/2
  kit.rod('Rotor spoke',(0,-1.07,.7),(math.cos(theta)*.27,-1.07+math.sin(theta)*.27,.7),.035,'steel',rotor)
 for x in [-1.65,1.65]:kit.rod('Operator handrail',(x,-1.28,.48),(x,-1.28,1.0),.05,'orange')

def module(kind):
 base(1.35,1.30)
 if kind=='atmosphere':
  for x in [-.32,.32]:tank(x,0,1.12,.24,1.28)
  fan=kit.pivot('Anim_Fan_Selective',(0,0,1.95))
  kit.ring('Intake protection',(0,0,1.95),.53,.06,'dark')
  for i in range(4):
   a=i*math.pi/2
   blade=kit.box('Fan blade',(math.cos(a)*.25,math.sin(a)*.25,1.95),(.42,.15,.055),'teal',.025,fan);blade.rotation_euler.z=a
 elif kind=='water':
  tank(.27,.05,1.18,.35,1.5)
  kit.box('Membrane cassette',(-.36,-.04,1.05),(.34,.7,1.3),'cream',.055)
  for z in [.65,.9,1.15,1.4]:kit.box('Cassette edge',(-.37,-.42,z),(.29,.07,.055),'teal',.012)
  kit.pipe('Return circuit',[(-.4,.3,.6),(-.5,.5,1.9),(.3,.5,2.0),(.3,.05,1.9)],.07,'steel')
  motor=kit.pivot('Anim_Agitator_Pump',(-.36,-.43,.5));kit.cyl('Pump impeller',(-.36,-.43,.5),.19,.12,'orange',parent=motor)
 elif kind=='thermal':
  kit.box('Exchange body',(0,0,1.1),(1.05,.45,1.4),'dark',.08)
  for z in [.6,.82,1.04,1.26,1.48,1.7]:kit.box('Heat exchanger fin',(0,0,z),(1.22,.9,.075),'steel',.02)
  kit.pipe('Heat loop',[(-.46,-.40,.48),(-.5,-.45,1.95),(.5,-.45,1.95),(.46,-.4,.48)],.085,'teal')
  fan=kit.pivot('Anim_Fan_Heat',(0,0,1.98));kit.box('Heat fan',(0,0,1.98),(.65,.14,.06),'orange',.025,fan)
 else:
  for x in [-.28,.28]:tank(x,0,.96,.25,1.1)
  kit.box('Culture header',(0,.18,1.65),(1.05,.44,.25),'cream',.06)
  kit.box('Culture window',(0,-.32,1.65),(.65,.06,.14),'culture',.02)
  mix=kit.pivot('Anim_Agitator_Culture',(0,0,1.85));kit.cyl('Culture mixer',(0,0,1.85),.22,.12,'orange',parent=mix)
  kit.pipe('Nutrient return',[(-.28,.25,.5),(-.48,.45,.5),(-.48,.45,1.7),(0,.18,1.7)],.065,'steel')

records=[]
for kind in ['source_control','atmosphere_module','water_module','thermal_module','biolab_module']:
 kit.reset()
 if kind=='source_control':source()
 else:module(kind.replace('_module',''))
 bpy.context.scene.unit_settings.system='METRIC';bpy.context.view_layer.update()
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(kind+'.blend')))
 ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(GAME/(kind+'.glb')),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 points=[o.matrix_world@Vector(c) for o in bpy.context.scene.objects if o.type=='MESH' for c in o.bound_box]
 records.append({'id':kind,'generator':'tools/build_terraform3.py','source':str((OUT/(kind+'.blend')).relative_to(ROOT)),'model':'terraform3/'+kind,'blender':bpy.app.version_string,'bounds_blender':[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]],'motion':[o.name for o in bpy.context.scene.objects if o.name.startswith('Anim_')]})
 kit.REVIEW=REVIEW;kit.render(kind)
 print('T3_ASSET',kind,flush=True)
(OUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
