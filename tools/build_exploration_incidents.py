"""T1/T2 encounter props. Blender authored, metre scale, separable functional parts."""
from pathlib import Path
exec((Path(__file__).parent/'build_exploration_discoveries.py').read_text().split('def build(id):')[0])
OUT=ROOT/'art/blender/incidents';GAME=ROOT/'우주-비즈니스/assets/models/incidents';REVIEW=ROOT/'docs/production/media/incidents-t2'
for p in [OUT,GAME,REVIEW]:p.mkdir(parents=True,exist_ok=True)
sapphire=mat('Incident sapphire',(.06,.18,.65),.25,.24)
ice=mat('Compressed glacier',(.21,.52,.65),.15,.3)
def label(text,loc,size,p):
 bpy.ops.object.text_add(location=loc,rotation=(math.pi/2,0,0));o=bpy.context.object;o.data.body=text;o.data.size=size;o.data.extrude=.002;o.data.align_x='CENTER';bpy.ops.object.convert(target='MESH');finish(bpy.context.object,'Manufacturer plate',cream,p)
def cargo(p,loc=(0,0,0)):
 x,y,z=loc;box('Pressure case',(x,y,z+.36),(1.1,.8,.72),teal,p,.12)
 box('Case lid',(x,y,z+.74),(1.15,.85,.13),cream,p,.05)
 for s in [-1,1]:
  box('Case strap',(x+s*.37,y,z+.39),(.1,.84,.74),dark,p,.025)
  box('Latch',(x+s*.37,y-.45,z+.57),(.16,.07,.2),orange,p,.025)
 cylinder('Folding handle',(x-.18,y,z+.86),(x+.18,y,z+.86),.045,steel,p)
def build(id):
 p=empty('Incident_'+id,(0,0,0));random.seed(id)
 if id in ['wreck','power']:
  # +Y in Blender exports to -Z: entrance at -2.4 and cargo at +4.4.
  box('Deck',(0,1.3,.13),(6,9,.26),dark,p,.08)
  for s in [-1,1]:
   box('Hull side',(s*3,1.3,1.8),(.35,9,3.6),cream,p,.17)
   box('Hull band',(s*3.19,1.3,1.5),(.08,8.2,.8),teal,p,.03)
   for y in [-2.8,-.2,2.4,5.2]:
    box('Pressure rib',(s*2.75,y,1.7),(.22,.18,3.2),steel,p,.045)
    box('External plating',(s*3.23,y,2.7),(.12,1.8,.4),dark,p,.025)
   cylinder('Broken engine',(s*3.8,2.6,1.2),(s*3.8,4.8,1.2),.7,dark,p)
   torus('Nozzle',(s*3.8,4.9,1.2),.58,.13,steel,p,rot=(math.pi/2,0,0))
  box('Aft bulkhead',(0,5.7,1.8),(6,.28,3.6),teal,p,.12)
  box('Roof fragment',(-1.9,1.3,3.5),(2.3,9,.23),cream,p,.1)
  for s in [-1,1]:box('Front jamb',(s*2.12,-2.4,1.8),(1.8,.35,3.6),teal,p,.12)
  box('Door lintel',(0,-2.4,3.1),(2.7,.38,.85),cream,p,.07)
  h=empty('Anim_Hatch',(0,-2.4,0),p);box('Sealed hatch',(0,-2.4,1.5),(2.5,.3,2.9),dark,h,.12)
  for x in [-.85,.85]:box('Door reinforcement',(x,-2.6,1.5),(.17,.16,2.6),orange,h,.04)
  torus('Manual lock',(0,-2.63,1.6),.37,.065,steel,h,rot=(math.pi/2,0,0))
  box('Socket pedestal',(2.2,-2.8,.55),(.55,.65,1.1),dark,p,.08);box('Power socket',(2.2,-3.16,1),(.4,.07,.4),orange,p,.04)
  for side in [-1,1]:
   panel('Torn stabilizer',[(side*3.1,.4,1.5),(side*6,3,.6),(side*5.1,4.4,.7),(side*3.1,3.6,1.7)],teal,p)
   cylinder('Sheared spar',(side*3.1,.4,1.5),(side*5.7,3,.6),.085,steel,p)
  panel('Cockpit broken shell',[(-2,-3.1,1.3),(-1.9,-5.3,.3),(-.8,-5.6,.35),(-.5,-3.1,1.8)],cream,p)
  for i in range(5):box('Scattered hull plates',(-3+i*.5,-5.2-i*.5,.12),(1.1,.7,.08),dark,p,.03,rot=(0,.1,i*.7))
  label('LOTUS / 07',(0,5.48,2.6),.38,p)
  for y in [-1,0,1,2,3,4]:box('Deck anti-slip',(0,y,.28),(2.1,.15,.015),steel,p,.006)
 elif id=='robot':
  from illuti_robot import build_robot
  build_robot(p,globals())
 elif id=='cliff':
  rock('Split cliff',(0,0,2),(2.5,2,2.35),rockmat,p)
  box('Old gantry',(0,0,4.6),(2.8,2.2,.2),steel,p,.05)
  for s in [-1,1]:
   cylinder('Gantry cable',(s,0,4.7),(s,0,7.2),.035,steel,p)
   cylinder('Support post',(s*1.4,.6,4.5),(s*1.4,.6,7.4),.1,teal,p)
  cylinder('Cross beam',(-1.4,.6,7.4),(1.4,.6,7.4),.1,teal,p)
  # Continuous walkable zigzag industrial steps, rise .22 m; landing at 4.8.
  for i in range(22):
   x=3.3 if i<11 else 1.9;y=-4.6+(i if i<11 else 21-i)*.55
   box('Access step',(x,y,(i+1)*.22-.11),(1.5,.7,.22),dark,p,.025)
  box('Top landing',(1,-4.6,4.7),(3.2,1.4,.24),steel,p,.04)
  for i in range(7):box('Top walkway',(0,-4+i*.55,4.7),(1.25,.65,.24),steel,p,.025)
 elif id=='ice':
  for s in [-1,1]:
   for y in [-1,1,3]:rock('Glacier wall',(s*2,y,1.6),(.85,1.3,2.0),ice,p)
  for y in [-1,1,3]:rock('Glacial roof',(0,y,3.2),(2.6,1.3,.8),ice,p)
  h=empty('Anim_Ice',(0,0,0),p);rock('Fractured ice plug',(0,-1.6,1.4),(1.65,.35,1.7),ice,h)
  for x in [-.8,0,.8]:cylinder('Ice fracture',(x,-2,0),(x+.4,-2,2.5),.025,cream,h)
 elif id=='drone':
  box('Flight core',(0,0,.15),(1.1,.9,.35),cream,p,.13)
  box('Optical pod',(0,-.5,.1),(.45,.24,.27),dark,p,.07)
  cylinder('Lens',(0,-.62,.1),(0,-.66,.1),.085,screen,p)
  for x in [-1,1]:
   for y in [-.8,.8]:
    cylinder('Rotor strut',(x*.4,y*.4,.1),(x,y,.1),.07,steel,p)
    torus('Rotor guard',(x,y,.2),.45,.04,teal,p)
    spin=empty('Anim_Rotor_'+str(x)+str(y),(x,y,.2),p)
    box('Propeller',(x,y,.2),(.8,.1,.035),dark,spin,.015)
  for x in [-.4,.4]:cylinder('Payload suspension',(x,0,.0),(x,0,-.55),.025,orange,p)
 elif id=='generator':
  box('Generator skid',(0,0,.12),(1.8,1.4,.24),dark,p,.08)
  cylinder('Alternator',(-.55,0,.75),(.55,0,.75),.48,teal,p)
  for x in [-.5,.5]:torus('Cooling ring',(x,0,.75),.49,.05,steel,p,rot=(0,math.pi/2,0))
  box('Service console',(0,-.6,1.05),(.75,.22,.58),cream,p,.08)
  box('Circuit display',(0,-.74,1.12),(.47,.03,.21),screen,p,.025)
  for x in [-.7,.7]:cylinder('Roll cage',(x,-.5,.3),(x,-.5,1.4),.055,orange,p)
 elif id=='battery':
  box('Battery body',(0,0,.35),(.48,.42,.7),orange,p,.08)
  for z in [.17,.35,.53]:box('Cooling groove',(0,-.22,z),(.34,.04,.04),dark,p,.008)
  for x in [-.14,.14]:cylinder('Terminal',(x,0,.7),(x,0,.79),.045,steel,p)
  cylinder('Carry handle',(-.18,0,.9),(.18,0,.9),.035,dark,p)
 elif id=='beacon':
  box('Beacon base',(0,0,.14),(.8,.75,.28),teal,p,.07)
  cylinder('Mast',(0,0,.2),(0,0,2.3),.055,steel,p)
  box('Telemetry unit',(0,0,1.7),(.42,.32,.6),cream,p,.07)
  lamp=empty('Anim_Lamp',(0,0,0),p);oval('Signal lamp',(0,0,2.4),(.1,.1,.13),screen,lamp)
  torus('Antenna',(0,0,2.7),.28,.035,steel,p,rot=(math.pi/2,0,0))
 elif id=='cargo':cargo(p)
 elif id=='nest':
  for i in range(13):
   a=i*math.tau/13;rock('Nest rubble',(math.cos(a)*1.6,math.sin(a)*1.4,.2),(.3,.24,.2),sandmat,p)
  for i in range(9):box('Stolen machine fragment',(random.uniform(-1.1,1.1),random.uniform(-1,1),.15),(.3,.15,.2),teal if i%2 else steel,p,.02,rot=(0,0,i))
 elif id=='gems':
  rock('Vent deposit',(0,0,-.12),(6.5,6.5,.30),rockmat,p)
  for i in range(6):
   q=empty('Anim_Gem_'+str(i),(0,0,0),p);a=i*math.tau/6
   shard('Sapphire prism',(math.cos(a)*.75,math.sin(a)*.65,.1),.75+i*.06,.22,sapphire,q)
 return p
ids=['wreck','robot','cliff','ice','drone','generator','battery','beacon','cargo','nest','gems']
exports=[] if "--render-only" in sys.argv else (["robot"] if "--robot-only" in sys.argv else (["wreck","gems"] if "--update" in sys.argv else ids))
for id in exports:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);build(id)
 bpy.context.scene.unit_settings.system='METRIC';bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(id+'.blend')))
 ink.consolidate_static_surfaces();bpy.ops.export_scene.gltf(filepath=str(GAME/(id+'.glb')),export_format='GLB',export_cameras=False,export_lights=False)
 print('INCIDENT_EXPORTED',id,flush=True)
if '--robot-only' in sys.argv:
 REVIEW=ROOT/'docs/production/media/illuti-remodel';REVIEW.mkdir(parents=True,exist_ok=True)
 ids=['robot']
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for i,id in enumerate(ids):
 p=build(id);p.location=Vector((0,0,0) if '--robot-only' in sys.argv else ((i%4-1.5)*12,(i//4-1)*15,0))
bpy.ops.mesh.primitive_plane_add(size=150,location=(0,0,-.2));bpy.context.object.data.materials.append(dark)
bpy.ops.object.camera_add(location=(32,-48,45));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=65;bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(0,-10,25));bpy.context.object.data.energy=16000;bpy.context.object.data.size=25
if '--robot-only' in sys.argv:
 cam.location=(4,-7,3.5);cam.rotation_euler=(Vector((0,0,1.45))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=4.5
 bpy.context.object.data.energy=1500;bpy.context.object.data.size=5;bpy.context.object.location=(2,-4,7)
s=bpy.context.scene;s.world.color=(.3,.3,.3);s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=1600;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.render.filepath=str(REVIEW/'blender.png')
if '--robot-only' in sys.argv:s.render.resolution_x=1200;s.render.resolution_y=1200
bpy.ops.render.render(write_still=True)
