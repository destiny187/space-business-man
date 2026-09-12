"""Blender INK firearm families. Editable originals, moving mechanisms, GLB and Cycles review."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
OUT=ROOT/'docs/production/media/ground-combat';OUT.mkdir(parents=True,exist_ok=True)
families=json.loads((ROOT/'우주-비즈니스/data/firearms.json').read_text())['families']
records=[]
def box(name,p,s,role='cream',bevel=.025,parent=None):return k.box(name,p,s,role,bevel,parent)
def barrel(name,p,radius,length,role='steel',parent=None):return k.cyl(name,p,radius,length,role,(math.pi/2,0,0),parent)
def pivot(name,p):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p;return o
def weapon(family):
 compact=family=='pistol';long=family in ['marksman','sniper'];heavy=family in ['lmg','plasma']
 length={'pistol':.42,'carbine':.70,'smg':.48,'shotgun':.82,'lmg':.85,'marksman':.92,'sniper':1.12,'plasma':.82}[family]
 width=.24 if heavy else .17
 box('Contoured receiver',(0,0,.08),(width,length*.6,.24),'teal',.045)
 box('Lower action frame',(0,-.06,-.08),(width*.82,length*.52,.12),'dark')
 grip=box('Raked pistol grip',(0,-.2,-.25),(.12,.14,.30),'dark',.032);grip.rotation_euler.x=-.20
 for z in [-.16,-.21,-.26,-.31]:box('Grip inset',(0,-.285,z),(.09,.025,.025),'teal',.008)
 k.pipe('Trigger guard',[(-.045,-.17,-.12),(-.045,-.07,-.12),(-.045,-.07,-.25),(-.045,-.17,-.25)],.015,'steel')
 box('Trigger',(0,-.12,-.15),(.02,.022,.08),'orange',.008)
 if not compact:
  box('Shoulder rail',(0,-length*.6,.04),(.11,length*.40,.10),'steel')
  box('Shoulder pad',(0,-length*.83,.01),(.20,.10,.27),'dark',.04)
  box('Stock cheek rest',(0,-length*.62,.16),(.16,length*.32,.08),'cream')
 action=pivot('Anim_Bolt',(0,.02,.12))
 box('Action slider',(.105,.02,.12),(.045,.19,.055),'steel',.01,action)
 box('Charging tab',(.135,-.03,.12),(.08,.04,.04),'orange',.01,action)
 magazine=pivot('Anim_Magazine',(0,.1,-.18))
 if family=='lmg':
  barrel('Drum core',(0,.10,-.24),.19,.25,'dark',magazine)
  barrel('Drum sideplate',(0,.24,-.24),.175,.035,'cream',magazine)
  for x in [-.26,.26]:
   k.rod('Folded bipod',(x*.45,length*.5,.01),(x,length*.65,-.20),.02,'steel')
 elif family=='plasma':
  barrel('Containment vessel',(0,.25,.12),.23,.45,'dark')
  for y in [.08,.2,.32,.44]:barrel('Segmented coil',(0,y,.12),.25,.035,'teal')
  for x in [-.21,.21]:box('Plasma guide rail',(x,.39,.12),(.06,.65,.10),'cream')
  barrel('Containment iris',(0,.54,.12),.21,.08,'orange')
  barrel('Charged aperture',(0,.59,.12),.14,.025,'status')
  box('Removable energy cell',(0,-.07,-.26),(.18,.25,.20),'cream',.04,magazine)
 else:
  box('Removable magazine',(0,.10,-.26),(.115,.20,.27 if family!='smg' else .36),'cream',.022,magazine)
  box('Magazine floor',(0,.10,-.41 if family!='smg' else -.46),(.15,.23,.045),'orange',.01,magazine)
 if family!='plasma':
  barrel('Free floating barrel',(0,length*.45,.09),.050 if not long else .045,length*.54,'steel')
  if family=='shotgun':
   barrel('Second barrel',(0,length*.45,-.04),.052,length*.54,'steel')
   pump=pivot('Anim_Pump',(0,length*.30,-.08))
   box('Pump foregrip',(0,length*.30,-.10),(.20,.25,.11),'orange',.025,pump)
   for y in [.15,.20,.25,.30]:box('Pump grip ribs',(0,y,-.15),(.21,.023,.025),'dark',.008,pump)
  else:
   box('Handguard',(0,length*.29,.06),(.20,length*.30,.20),'cream',.035)
   for y in [length*.20,length*.29,length*.38]:
    for x in [-.102,.102]:box('Cooling port',(x,y,.08),(.015,.052,.075),'dark',.008)
  barrel('Muzzle collar',(0,length*.74,.09),.07,.085,'dark')
  barrel('Emitter ring',(0,length*.79,.09),.062,.025,'orange')
  barrel('Bore aperture',(0,length*.81,.09),.04,.015,'dark')
  barrel('Emitter core',(0,length*.82,.09),.021,.01,'status')
 socket=pivot('Socket_Muzzle',(0,.60 if family=='plasma' else length*.83,.12 if family=='plasma' else .09))
 if long:
  box('Optic riser',(0,-.06,.27),(.10,.19,.12),'dark')
  barrel('Precision optic',(0,-.01,.36),.08,.39 if family=='sniper' else .24,'dark')
  barrel('Objective hood',(0,.20 if family=='sniper' else .13,.36),.095,.04,'cream')
  barrel('Optic glass',(0,.223 if family=='sniper' else .153,.36),.063,.012,'status')
  box('Adjustment dial',(.095,-.05,.36),(.055,.07,.075),'orange',.015)
 elif not compact:
  box('Sight rail',(0,0,.235),(.12,.24,.05),'dark')
  for x in [-.07,.07]:box('Open sight upright',(x,0,.30),(.025,.055,.12),'steel',.006)
  box('Open sight bridge',(0,0,.365),(.16,.055,.025),'orange',.006)
 else:
  box('Front sight',(0,.20,.225),(.035,.045,.045),'orange',.006)
 for x in [-width*.52,width*.52]:
  box('Service hatch',(x,-.08,.06),(.025,.17,.12),'cream',.018)
  for y in [-.13,-.03]:k.cyl('Recessed fastener',(x*1.04,y,.065),.013,.012,'steel',(0,math.pi/2,0))

for family,spec in families.items():
 k.reset();weapon(family);scene=bpy.context.scene;scene.unit_settings.system='METRIC'
 source=ROOT/'art/blender/equipment'/('gun_'+family+'.blend');source.parent.mkdir(parents=True,exist_ok=True)
 output=ROOT/'우주-비즈니스/assets/models/equipment'/('gun_'+family+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 records.append({'id':'gun_'+family,'name':spec['name'],'source':str(source.relative_to(ROOT)),'model':'res://assets/models/equipment/gun_'+family+'.glb','motion':['Anim_Bolt','Anim_Magazine'],'generator':'tools/build_firearms.py','style':'INK v1'})
 scene.world=bpy.data.worlds.new('Firearm review');scene.world.color=(.18,.18,.18)
 bpy.ops.object.camera_add(location=(1.5,1.8,1.15));cam=bpy.context.object
 cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.3;scene.camera=cam
 for p,e in [((1,1,3),240),((-1,0,2),160)]:
  bpy.ops.object.light_add(type='AREA',location=p);light=bpy.context.object;light.data.energy=e;light.data.size=3
 scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=720;scene.render.resolution_y=540;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(family+'-blender.png'));bpy.ops.render.render(write_still=True)
(ROOT/'art/blender/equipment/firearms.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'우주-비즈니스/data/render_assets.json';assets=json.loads(p.read_text())
for row in records:
 assets=[a for a in assets if a['id']!=row['id']]
 assets.append(dict(row,title=row['name'],group='장비',geometry='ink-family-remodeled',foliage=False))
p.write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n')
print('FIREARMS_EXPORTED',len(records))
