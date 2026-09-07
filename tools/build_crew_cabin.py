"""Editable INK expedition cabin and rigged survey suit, authored in Blender."""
from pathlib import Path
import bpy, math, json, sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from surveyor_rig import export_suit
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/crew'; OUTPUT=ROOT/'우주-비즈니스/assets/models/crew'
SOURCE.mkdir(parents=True,exist_ok=True); OUTPUT.mkdir(parents=True,exist_ok=True)
def clear():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,hexcolor,metal=.15):
 rgb=tuple(int(hexcolor[i:i+2],16)/255 for i in (0,2,4))
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.62
 return m
P={k:material(k,c) for k,c in dict(cream='c7c9af',teal='175e61',dark='13272f',steel='5d767b',orange='dc7132',glass='193e50',light='a1d8ca').items()}
def loc(p):return (p[0],-p[2],p[1])
def finish(o,name,key,bevel=.03,parent=None):
 o.name=name;o.data.materials.append(P[key])
 if bevel:
  m=o.modifiers.new('Soft manufactured edge','BEVEL');m.width=bevel;m.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 for f in o.data.polygons:f.use_smooth=True
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o
def box(name,p,s,key,bevel=.035,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,key,bevel,parent)
def sphere(name,p,s,key,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=loc(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,key,0,parent)
def pivot(name,p):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc(p);bpy.context.view_layer.update();return o
def export(name):
 if name=='surveyor_suit':
  tris, surfaces, bones=export_suit(SOURCE/(name+'.blend'), OUTPUT/(name+'.glb'))
  return {'source':str((SOURCE/(name+'.blend')).relative_to(ROOT)), 'output':str((OUTPUT/(name+'.glb')).relative_to(ROOT)), 'triangles':tris, 'surfaces':surfaces, 'bones':bones, 'style':'ink-v1', 'status':'articulated-locomotion'}
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o
  for modifier in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
  groups.setdefault((o.parent.name if o.parent else '',o.data.materials[0].name),[]).append(o)
 for objects in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
 bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+'.glb')),export_format='GLB',export_yup=True)
 tris=0
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
 return {'source':str((SOURCE/(name+'.blend')).relative_to(ROOT)),'output':str((OUTPUT/(name+'.glb')).relative_to(ROOT)),'triangles':tris,'surfaces':len(groups),'style':'ink-v1','status':'game-review-required'}
clear()
box('Pressure deck',(0,-.22,0),(8,.44,16),'dark',.12)
for z in range(-7,8,2):
 for x in [-2.9,0,2.9]:
  box('Removable deck plate',(x,-.015,z),(2.75,.12,1.90),'steel' if x==0 else 'teal',.055)
 for x in [-1.49,1.49]:box('Aisle safety stripe',(x,.055,z),(.045,.014,1.6),'orange',.005)
for side in [-1,1]:
 box('Pressure wall',(side*4,1.9,0),(.24,4.2,16),'dark',.09)
 for z in [-6,-3,0,3,6]:
  box('Ceramic wall liner',(side*3.84,2,z),(.12,2.75,2.77),'cream',.08)
  box('Frame rib',(side*3.65,1.9,z-1.45),(.31,3.8,.22),'teal',.08)
  box('Low service rail',(side*3.69,.39,z),(.23,.25,2.8),'dark',.035)
  box('Upper cable raceway',(side*3.64,3.49,z),(.25,.25,2.8),'dark',.04)
  box('Interior light strip',(side*3.5,3.35,z),(.055,.075,1.9),'light',.015)
 for z in [-4,-1,2]:
  box('Seat plinth',(side*2.65,.27,z),(.65,.54,.65),'steel',.08)
  box('Seat cushion',(side*2.65,.61,z),(.89,.22,.87),'dark',.12)
  box('Armored seat back',(side*2.65,1.22,z+.43),(.97,1.23,.23),'teal',.15)
  box('Shoulder cushion',(side*2.65,1.62,z+.27),(.7,.37,.16),'dark',.075)
  for dx in [-.32,.32]:box('Safety harness',(side*2.65+dx,1.16,z+.28),(.055,.76,.04),'orange',.012)
  for dx in [-.52,.52]:box('Seat armrest',(side*2.65+dx,.93,z),(.12,.16,.73),'cream',.06)
  box('Seat indicator',(side*2.65,1.97,z+.42),(.35,.09,.07),'light',.018)
box('Ceiling pressure shell',(0,4.03,0),(8,.2,16),'dark',.08)
for z in [-6,-3,0,3,6]:
 box('Ceiling arch',(0,3.86,z),(7.8,.20,.3),'teal',.055)
 for x in [-2,2]:box('Ceiling ceramic panel',(x,3.96,z),(3.3,.07,2.7),'cream',.06)
box('Window sill',(0,.65,-7.84),(8,1.3,.28),'teal',.1)
box('Window header',(0,3.72,-7.84),(8,.58,.28),'teal',.1)
for x in [-3.83,3.83]:box('Window jamb',(x,2.15,-7.84),(.34,2.7,.28),'cream',.08)
for x in [-2.7,2.7]:
 box('Flight console pedestal',(x,.7,-6.65),(1.58,1.25,.86),'dark',.12)
 o=box('Slanted flight console',(x,1.37,-6.58),(1.68,.16,1.04),'teal',.1);o.rotation_euler.x=math.radians(12)
 box('Inset avionics display',(x,1.47,-6.73),(1.2,.025,.49),'glass',.035)
 for dx in [-.46,-.23,0,.23,.46]:box('Flight keys',(x+dx,1.46,-6.29),(.13,.035,.12),'orange' if dx==0 else 'cream',.016)
box('Aft pressure bulkhead',(0,1.9,7.98),(8,4,.22),'cream',.09)
box('Airlock seal',(0,1.55,7.79),(2.36,3.15,.18),'dark',.12)
for x in [-.51,.51]:
 box('Airlock panel',(x,1.5,7.65),(.98,2.86,.18),'teal',.09)
 box('Airlock grip',(x,1.45,7.51),(.10,.51,.10),'orange',.035)
box('Shared locker',(0,.59,5.6),(1.7,1.18,.85),'teal',.12)
box('Locker lid',(0,1.21,5.6),(1.81,.15,.94),'cream',.06)
for x in [-.48,.48]:box('Locker latch',(x,.93,5.13),(.19,.27,.07),'orange',.025)
cabin=export('kestrel_cabin') if '--suit-only' not in sys.argv else None
clear()
# Rounded pressure suit: seam layering and independent arm/leg pivots.
box('Life support pack',(0,1.19,.23),(.53,.63,.34),'teal',.09)
for x in [-.22,.22]:sphere('Air canister',(x,1.19,.43),(.13,.30,.13),'cream')
sphere('Torso pressure envelope',(0,1.13,0),(.34,.37,.22),'dark')
box('Ceramic breastplate',(0,1.24,-.19),(.59,.40,.11),'cream',.09)
box('Chest instrument panel',(0,1.24,-.262),(.23,.19,.044),'teal',.03)
for x in [-.065,.065]:box('Chest warning lamps',(x,1.28,-.29),(.038,.045,.025),'orange',.008)
box('Utility belt',(0,.92,-.015),(.63,.10,.45),'teal',.035)
for x in [-.24,.24]:box('Belt toolkit',(x,.94,-.25),(.17,.18,.09),'orange',.025)
sphere('Helmet pressure shell',(0,1.69,0),(.275,.30,.26),'cream')
sphere('Recessed visor frame',(0,1.70,-.125),(.259,.209,.187),'dark')
sphere('Panoramic visor',(0,1.70,-.154),(.224,.168,.182),'glass')
box('Helmet crest',(0,1.954,.01),(.10,.045,.25),'teal',.018)
for x in [-.285,.285]:sphere('Comms receiver',(x,1.66,.035),(.052,.11,.10),'teal')
for side in [-1,1]:
 arm=pivot('Anim_Arm_'+('L' if side<0 else 'R'),(side*.39,1.35,0))
 sphere('Shoulder pauldron',(side*.40,1.32,0),(.16,.18,.19),'teal',arm)
 sphere('Upper arm sleeve',(side*.43,1.13,0),(.13,.21,.13),'cream',arm)
 sphere('Elbow gasket',(side*.45,.96,-.025),(.125,.115,.12),'dark',arm)
 box('Gauntlet',(side*.46,.83,-.045),(.24,.22,.25),'teal',.07,arm)
 sphere('Glove',(side*.46,.68,-.075),(.12,.12,.13),'dark',arm)
 leg=pivot('Anim_Leg_'+('L' if side<0 else 'R'),(side*.18,.85,0))
 sphere('Upper leg pressure fabric',(side*.18,.66,0),(.155,.25,.16),'cream',leg)
 sphere('Knee gasket',(side*.18,.43,0),(.15,.12,.15),'dark',leg)
 box('Knee guard',(side*.18,.44,-.12),(.21,.17,.09),'orange',.05,leg)
 box('Shin armor',(side*.18,.26,0),(.26,.26,.27),'teal',.07,leg)
 box('Magnetic boot',(side*.18,.09,-.09),(.30,.18,.49),'dark',.065,leg)
 box('Boot toecap',(side*.18,.12,-.24),(.27,.12,.18),'cream',.045,leg)
suit=export('surveyor_suit')
clear()
box('Recovery crate shell',(0,.29,0),(.78,.54,.51),'teal',.07)
box('Sealed lid',(0,.59,0),(.83,.10,.55),'cream',.035)
for side in [-1,1]:
 box('Reinforced corner rail',(side*.35,.28,0),(.09,.54,.55),'dark',.025)
 box('Orange latch',(side*.23,.44,-.28),(.12,.17,.07),'orange',.018)
 box('Carry grip',(side*.46,.32,0),(.13,.08,.23),'steel',.03)
 for z in [-.22,.22]:sphere('Rail fastener',(side*.36,.58,z),(.025,.012,.025),'steel')
box('Cargo identification strip',(0,.29,-.266),(.30,.095,.018),'cream',.008)
crate=export('recovery_crate') if '--suit-only' not in sys.argv else None
if '--suit-only' in sys.argv:
 prior=json.loads((SOURCE/'manifest.json').read_text())
 cabin=prior['assets'][0];crate=prior['assets'][2]
(SOURCE/'manifest.json').write_text(json.dumps({'generator':'tools/build_crew_cabin.py','assets':[cabin,suit,crate]},indent=2)+'\n')
print('CREW_EXPORTED',cabin,suit)
