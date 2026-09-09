"""20 authored T1/T2 discoveries. Blender Z-up, game Y-up; metres and INK materials.
Source retains parts; export keeps Anim_ pivots, Cover_ and sample silhouettes.
"""
from pathlib import Path
exec((Path(__file__).parent/'build_scout_rover.py').read_text().split("root=empty('SCOUT_Rover'")[0])
import random
OUT=ROOT/'art/blender/discoveries';GAME=ROOT/'우주-비즈니스/assets/models/discoveries';REVIEW=ROOT/'docs/production/media/exploration-t2'
for path in [OUT,GAME,REVIEW]:path.mkdir(parents=True,exist_ok=True)
rockmat=mat('Discovery basalt',(.16,.21,.25),.05,.83)
sandmat=mat('Discovery sediment',(.42,.30,.18),0,.92)
bone=mat('Discovery fossil ivory',(.65,.54,.34),0,.72)
crystal=mat('Discovery mineral teal',(.09,.43,.48),.3,.24)
leaf=mat('Discovery ancient leaf',(.16,.34,.12),0,.76)
glow=mat('Discovery luminous algae',(.08,.72,.49),0,.5,emission=.7)
watermat=mat('Discovery water',(.04,.24,.3),.25,.22)

def oval(name,loc,scale,m,p=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for f in o.data.polygons:f.use_smooth=True
 return finish(o,name,m,p)
def rock(name,loc,scale,m,p=None):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object
 for v in o.data.vertices:v.co*=1+random.uniform(-.13,.13)
 o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,m,p,.025)
def torus(name,loc,major,minor,m,p=None,rot=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=12,location=loc,major_radius=major,minor_radius=minor,rotation=rot)
 o=bpy.context.object
 for f in o.data.polygons:f.use_smooth=True
 return finish(o,name,m,p)
def shard(name,loc,h,r,m,p=None,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=r,radius2=0,depth=h,location=(loc[0],loc[1],loc[2]+h/2));o=bpy.context.object;o.rotation_euler=rot;return finish(o,name,m,p,.012)
def sediment(p,r=2):
 rock('Layered outcrop',(0,0,.08),(r,r*.72,.23),sandmat,p)
 for i in range(8):
  a=i*math.tau/8;rock('Fracture fragment',(math.cos(a)*r*.9,math.sin(a)*r*.66,.13),(.24,.20,.13),rockmat,p)
def seal(p,loc=(0,0,1)):
 o=empty('Anim_Cover',loc,p);box('Removable panel',loc,(1.4,.75,.18),sandmat,o,.07);return o

def build(id):
 root=empty('Discovery_'+id,(0,0,0));random.seed(id)
 if id=='singing_stones':
  for i in range(3):
   x=(i-1)*2.4;h=2.8+i*.8
   for side in [-1,1]:rock('Wind flute pier',(x+side*.52,0,h/2),(.42,.8,h/2),rockmat,root)
   rock('Flute lintel',(x,0,h),(1.0,.8,.30),sandmat,root)
   for j in range(3):box('Erosion ledge',(x,0,.25+j*.4),(1.5,.95,.13),sandmat,root,.06)
 elif id=='meteor_glass':
  sediment(root,2.8)
  for i in range(11):
   a=i*.48;shard('Impact glass',(math.cos(a)*1.6,math.sin(a)*1.05,.12),random.uniform(.6,2.7),.3,crystal if i%3==0 else dark,root,rot=(.25,0,a))
 elif id=='dew_basin':
  sediment(root);oval('Basin',(0,0,.18),(1.7,1.3,.28),rockmat,root);torus('Condensation rim',(0,0,.4),1.05,.18,sandmat,root)
  oval('Collected dew',(0,0,.39),(1.05,.84,.06),watermat,root)
  for i in range(13):oval('Dew beads',(.9*math.cos(i),.9*math.sin(i),.51),(.045,.045,.04),crystal,root)
 elif id=='salt_bloom':
  sediment(root)
  for i in range(7):
   x=random.uniform(-1.5,1.5);y=random.uniform(-1,1)
   for j in range(6):shard('Salt petal',(x,y,.2),.6,.18,bone,root,rot=(.7*math.cos(j),.7*math.sin(j),j))
 elif id=='molting_trail':
  for i,(x,y) in enumerate([(0,0),(5,3),(10,6)]):
   torus('Shed shell',(x,y,.48),.65+i*.1,.12,bone,root,rot=(math.pi/2,.25,0))
   for j in range(5):oval('Shell lamella',(x+(j-2)*.22,y,.55),(.12,.55,.18),bone,root)
   for step in range(6):oval('Track',(x-step*.45,y-step*.28,.035),(.16,.09,.025),dark,root)
 elif id=='fossil_ripples':
  sediment(root,2.5)
  for i in range(7):
   cylinder('Ripple crest',(-2,-1.3+i*.42,.27),(2,-1.3+i*.42,.27),.045,bone,root)
  for i in range(5):
   for digit in [-1,0,1]:cylinder('Fossil toe',(-1+i*.45,-.6+i*.2,.31),(-1+i*.45+digit*.12,-.36+i*.2,.32),.045,dark,root)
  seal(root,(0,0,.42))
 elif id=='seed_pockets':
  sediment(root)
  for i in range(6):
   a=i*math.tau/6;oval('Seed husk',(math.cos(a)*.8,math.sin(a)*.65,.6),(.30,.18,.55),leaf,root)
   oval('Dormant kernel',(math.cos(a)*.72,math.sin(a)*.6,.72),(.12,.14,.19),orange,root)
 elif id=='iron_sand_ribbons':
  sediment(root,2.4)
  for i in range(7):
   for j in range(8):oval('Magnetic sand',(-2+j*.55,-1.2+i*.4+math.sin(j*.7)*.13,.30),(.35,.065,.04),dark,root)
 elif id=='shell_shelter':
  # Large hollow ribbed shell, open at the front and inside.
  for j in range(8):
   y=-1.4+j*.42;r=1.8-math.sin(j*.32)*.35
   for i in range(12):
    a=i*math.pi/11;b=(i+1)*math.pi/11
    cylinder('Shelter rib',(r*math.cos(a),y,r*math.sin(a)+.15),(r*math.cos(b),y,r*math.sin(b)+.15),.11,bone,root)
  for i in range(7):oval('Refuge growth',(random.uniform(-.7,.7),random.uniform(-1,1),.10),(.22,.2,.12),leaf,root)
 elif id in ['fallen_survey_pod','submerged_recorder','abandoned_drill']:
  sediment(root,1.6)
  box('Crash chassis',(0,0,.46),(1.5,2.1,.6),dark,root,.18,rot=(0,.08,.1))
  box('Armoured instrument',(0,0,1.0),(1.35,1.6,.75),cream,root,.20)
  box('Recessed control',(0,.82,1.05),(.8,.05,.42),dark,root,.04)
  box('Telemetry lamp',(0,.86,1.08),(.59,.03,.16),screen,root,.02)
  cover=empty('Anim_Cover',(0,-.65,1.45),root);box('Access hatch',(0,0,1.48),(1.40,1.42,.17),teal,cover,.07)
  for x in [-.58,.58]:
   cylinder('Pressure strap',(x,-.65,.5),(x,-.65,1.50),.06,steel,root)
   box('Release latch',(x,.75,1.4),(.16,.14,.21),orange,root,.025)
  if id=='fallen_survey_pod':
   cylinder('Bent mast',(.60,-.55,1.4),(1.4,-.5,2.6),.065,steel,root);torus('Antenna',(1.4,-.5,2.6),.48,.055,teal,root,rot=(1.1,0,0))
  elif id=='abandoned_drill':
   spin=empty('Anim_Rotor',(0,1.1,.7),root)
   cylinder('Borer barrel',(0,1.0,.7),(0,2.5,.7),.36,steel,spin)
   for i in range(7):torus('Drill cutting ring',(0,1.1+i*.2,.7),.4-i*.026,.07,teal,spin,rot=(math.pi/2,0,0))
  else:
   for x in [-.9,.9]:cylinder('Recorder recovery handle',(x,-.5,.7),(x,.5,.7),.065,orange,root)
 elif id=='hollow_geode':
  # Half-open interior with removable crust; large enough to step inside after opening.
  for i in range(11):
   a=i*math.tau/11
   if math.sin(a)>.45:continue
   rock('Geode wall',(math.cos(a)*1.7,math.sin(a)*1.4,1.2),(.85,.6,1.4),rockmat,root)
   shard('Inner crystal',(math.cos(a)*1.12,math.sin(a)*.8,.15),1+random.random(),.24,crystal,root)
  cover=empty('Anim_Cover',(0,1.2,0),root);rock('Breakable crust',(0,1.2,1.25),(1.8,.38,1.4),sandmat,cover)
  for i in range(7):shard('Floor crystals',(random.uniform(-.8,.8),random.uniform(-.5,.5),.1),.5,.13,crystal,root)
 elif id=='luminous_tidepool':
  for i in range(12):
   a=i*math.tau/12;rock('Pool lip',(math.cos(a)*1.7,math.sin(a)*1.1,.12),(.4,.3,.20),rockmat,root)
  oval('Pool',(0,0,.10),(1.7,1.1,.06),watermat,root)
  living=empty('Anim_Glow',(0,0,0),root)
  for i in range(15):oval('Algae colonies',(random.uniform(-1.3,1.3),random.uniform(-.8,.8),.16),(.15,.12,.08),glow,living)
  cover=empty('Anim_Cover',(0,-1.2,0),root);box('Folded shade canopy',(0,-1.25,.3),(3.7,.35,.12),teal,cover,.03)
 elif id=='buried_aqueduct':
  for x in [-1.15,1.15]:box('Stone canal bank',(x,0,.5),(.5,5.5,1.0),sandmat,root,.1)
  box('Canal bed',(0,0,.12),(2,5.5,.24),rockmat,root,.08)
  for y in [-2,0,2]:
   for x in [-1.4,1.4]:box('Aqueduct buttress',(x,y,.5),(.6,.5,.9),rockmat,root,.05)
  gate=empty('Anim_Cover',(0,0,0),root);box('Silt gate',(0,.6,.7),(2,.4,1.3),sandmat,gate,.05)
  wheel=empty('Anim_Rotor',(1.5,.6,1.2),root);torus('Gate wheel',(1.5,.6,1.2),.35,.06,orange,wheel,rot=(0,math.pi/2,0))
 elif id=='thermal_chimneys':
  sediment(root,2.6)
  for i in range(5):
   a=i*2.3;x=math.cos(a)*1.5;y=math.sin(a);h=.9+i*.35
   cylinder('Thermal chimney',(x,y,0),(x,y,h),.42,rockmat,root)
   torus('Mineral vent lip',(x,y,h),.32,.12,sandmat,root)
   cylinder('Dark vent throat',(x,y,h+.005),(x,y,h+.025),.22,dark,root)
 elif id=='spore_sails':
  for i in range(3):
   x=i*5;y=i*3;stem=empty('Anim_Sail_'+str(i),(x,y,0),root)
   cylinder('Spore stem',(x,y,0),(x,y,1.9),.06,leaf,stem)
   oval('Seed carrier',(x,y,1.4),(.28,.18,.4),orange,stem)
   panel('Wind membrane',[(x-1,y,2.3),(x,y,2.8),(x+1,y,2.2),(x,y,1.1)],bone,stem)
 elif id=='magnetic_arch':
  for i in range(13):
   a=i*math.pi/12;x=2.8*math.cos(a);z=2.8*math.sin(a)
   rock('Magnetic arch',(x,0,z+.35),(.55,.75,.65),rockmat,root)
   shard('Polar crystal',(x,.6,z+.4),.35,.15,crystal,root,rot=(0,a,0))
  for i in range(7):torus('Particle trace',(0,0,.035+i*.004),.65+i*.23,.025,dark,root)
 elif id=='fossil_nest':
  sediment(root,2.5)
  for i in range(16):
   a=i*math.tau/16;rock('Nest rim',(math.cos(a)*1.5,math.sin(a)*1.2,.3),(.32,.25,.18),bone,root)
  for i in range(5):oval('Fossil egg',((i%3-1)*.6,(i//3-.5)*.8,.4),(.32,.38,.34),bone,root)
  seal(root,(0,0,.65))
 elif id=='mirror_canyon':
  for x in [-2.5,2.5]:
   for i in range(4):
    h=2.5+random.random()*1.8;rock('Canyon wall',(x,-1.8+i*1.15,h/2),(.7,1.0,h/2),rockmat,root)
    box('Natural reflective plate',(x*.84,-1.8+i*1.15,h*.63),(.10,.7,h*.48),crystal,root,.05,rot=(0,.1*x,.14))
 return root

catalog=json.loads((ROOT/'우주-비즈니스/data/exploration_discoveries.json').read_text())
ids=list(catalog['items'])
for id in ([] if "--review-only" in sys.argv else ids):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 build(id);bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(id+'.blend')))
 ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(GAME/(id+'.glb')),export_format='GLB',export_cameras=False,export_lights=False)
 print('DISCOVERY_EXPORTED',id,flush=True)
# Render authored shapes together in Blender, before Godot INK review.
for page in range(2):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 for i,id in enumerate(ids[page*10:(page+1)*10]):
  obj=build(id);obj.location=Vector((((i%5)-2)*13,(i//5-.5)*17,0))
 bpy.ops.mesh.primitive_plane_add(size=150,location=(0,0,-.15));bpy.context.object.data.materials.append(mat('Review floor',(.10,.14,.17),0,.8))
 bpy.ops.object.camera_add(location=(30,40,52));cam=bpy.context.object;cam.rotation_euler=(Vector((1,3,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=96;bpy.context.scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(0,5,25));bpy.context.object.data.energy=16000;bpy.context.object.data.size=25
 scene=bpy.context.scene;scene.world.color=(.3,.3,.3);scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/f'blender-t{page+1}.png');bpy.ops.render.render(write_still=True)
print('DISCOVERY_ASSETS_COMPLETE',flush=True)
