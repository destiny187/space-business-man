"""Discovery-driven condenser and hydrothermal generator, Blender sources and renders."""
from pathlib import Path
import sys, math, json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
OUT=ROOT/'output/discovery-industry';OUT.mkdir(parents=True,exist_ok=True)
def deck(width,depth):
 k.box('Foundation',(0,0,.16),(width,depth,.32),'dark',.1)
 k.box('Service deck',(0,0,.35),(width-.12,depth-.12,.14),'steel',.045)
 for x in [-width*.4,width*.4]:
  for y in [-depth*.4,depth*.4]:k.cyl('Anchor',(x,y,.13),.22,.3,'teal')
def natural_materials():
 for role,color in [('stone',(0.29,.34,.33,1)),('rim',(.43,.35,.22,1)),('wet',(.045,.19,.22,1)),('moss',(.12,.21,.13,1))]:
  mat=bpy.data.materials.new('Natural '+role);mat.diffuse_color=color;mat.use_nodes=True
  mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
  mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.83
  k.P[role]=mat

def shaped(name,center,profile,role,phase=0):
 # Uneven mineral growth rings preserve a natural silhouette around a manufactured core.
 n=48;vertices=[];faces=[]
 for ring,(radius,z) in enumerate(profile):
  for i in range(n):
   a=i*math.tau/n;rough=1+.045*math.sin(a*5+phase)+.025*math.sin(a*9+z)
   vertices.append((center[0]+radius*rough*math.cos(a),center[1]+radius*rough*math.sin(a),center[2]+z+.02*math.sin(a*4+phase)))
 for ring in range(len(profile)-1):
  for i in range(n):
   j=(i+1)%n;faces.append((ring*n+i,ring*n+j,(ring+1)*n+j,(ring+1)*n+i))
 faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
 obj.data.materials.append(k.P[role])
 for f in mesh.polygons:f.use_smooth=True
 return obj

def basin(name,center,radius,height):
 shaped(name,center,[(.08*radius,0),(.65*radius,.08*height),(.95*radius,.55*height),(radius,.85*height),(.96*radius,height),(.82*radius,.91*height),(.75*radius,.44*height),(.08*radius,.3*height)],'rim',center[0]*2)
 k.cyl(name+' collected water',(center[0],center[1],center[2]+height*.44),radius*.72,.025,'wet')

def condenser():
 natural_materials()
 # A stepped stone catchment is the visible body; refrigeration is a small attached service unit.
 shaped('Mineral foundation',(0,0,.12),[(.1,0),(1.7,0),(1.76,.18),(1.5,.3),(.1,.31)],'stone')
 for x,y,z,h in [(-.48,.33,.32,1.25),(.85,.37,.28,.6),(.85,-.66,.28,.28)]:
  shaped('Eroded basin pedestal',(x,y,z),[(.43,0),(.35,h*.4),(.4,h*.75),(.34,h)],'stone',x)
 basin('Main dew stone',(-.48,.33,1.52),1.12,.73)
 basin('Cascade stone',(.85,.37,.83),.64,.48)
 basin('Return stone',(.85,-.66,.52),.55,.37)
 for a in [math.pi*.2,math.pi*.95,math.pi*1.55]:
  x=-.48+math.cos(a)*1.01;y=.33+math.sin(a)*1.01
  k.box('Removable rim clamp',(x,y,1.99),(.15,.22,.32),'teal',.03)
 k.pipe('Dew channel',[(-.0,-.28,1.96),(.42,-.22,1.65),(.75,.25,1.06)],.05,'steel')
 k.pipe('Gravity return',[(.85,-.14,1.13),(.88,-.38,.9),(.85,-.6,.72)],.045,'steel')
 k.box('Refrigeration service pack',(-.73,-.86,.85),(.88,.56,.9),'teal',.11)
 for z in [.57,.76,.95]:k.box('Cooling fin',(-.73,-1.17,z),(.68,.08,.075),'steel',.015)
 k.pipe('Intake loop',[(.85,-.9,.65),(.2,-1.08,.43),(-.55,-1.08,.5)],.05,'steel')
 k.box('Ice outlet',(-.73,-1.17,1.25),(.68,.32,.16),'cream',.03)
 for x in [-.94,-.72,-.5]:k.box('Frozen condensate',(x,-1.15,1.37),(.16,.19,.13),'status',.025)
 k.cyl('Vent casing',(-.72,-.87,1.41),.25,.14,'dark')
 fan=k.pivot('Anim_Fan_Condenser',(-.72,-.87,1.5))
 for i in range(4):
  a=i*math.pi*.5;o=k.box('Vent blade',(-.72+.13*math.cos(a),-.87+.13*math.sin(a),1.5),(.2,.065,.04),'steel',.012,parent=fan);o.rotation_euler.z=a
 k.box('Moisture meter',(-1.15,-.86,.96),(.24,.17,.38),'teal',.035)
 k.box('Meter display',(-1.15,-.96,1.01),(.16,.025,.2),'status',.01)
 for x,y in [(-1.15,.97),(.87,.95),(1.25,-.5)]:shaped('Mineral patina',(x,y,.38),[(.04,0),(.18,.04),(.1,.1)],'moss',x)

def chimney(center,radius,height):
 shaped('Hollow hydrothermal growth',center,[(radius*.95,0),(radius*.85,height*.23),(radius*1.05,height*.5),(radius*.84,height*.7),(radius,height),(radius*.7,height+.01),(radius*.64,height-.32),(radius*.03,height-.42)],'stone',height)
 k.ring('Mineral growth lip',(center[0],center[1],center[2]+height),radius*.85,radius*.13,'rim')
 k.cyl('Warm inner vent',(center[0],center[1],center[2]+height-.32),radius*.56,.035,'orange')

def geothermal():
 natural_materials()
 shaped('Mineral outcrop',(0,0,.1),[(.1,0),(1.96,0),(1.86,.23),(1.65,.38),(.1,.4)],'stone',1)
 chimney((-.63,.5,.36),.52,2.75)
 chimney((.55,.8,.35),.39,2.05)
 chimney((-.99,-.55,.33),.35,1.4)
 for center,radius,z in [((-.63,.5),.52,1.05),((-.63,.5),.49,2.24),((.55,.8),.37,1.05),((-.99,-.55),.34,.85)]:
  k.ring('Split heat collection collar',(center[0],center[1],z),radius+.035,.065,'steel')
  k.box('Collar fastener',(center[0],center[1]-radius-.09,z),(.23,.16,.16),'teal',.025)
 k.box('Attached turbine module',(.67,-.58,.99),(1.02,.92,1.12),'teal',.14)
 k.cyl('Turbine grille',(.67,-.58,1.62),.45,.12,'dark')
 fan=k.pivot('Anim_Fan_Turbine',(.67,-.58,1.72))
 for i in range(6):
  a=i*math.tau/6;o=k.box('Turbine blade',(.67+.24*math.cos(a),-.58+.24*math.sin(a),1.72),(.34,.11,.045),'steel',.015,parent=fan);o.rotation_euler.z=a+.2
 k.pipe('Primary heat loop',[(-.63,.05,2.24),(-.24,-.1,2.03),(.48,-.2,1.42)],.08,'steel')
 k.pipe('Secondary return',[(.55,.48,1.05),(1.13,.17,.65),(.99,-.35,.65)],.065,'steel')
 k.pipe('Low vent pickup',[(-.99,-.88,.85),(-.3,-1.03,.58),(.4,-1.03,.67)],.06,'steel')
 k.box('Power connector',(.67,-1.08,.96),(.55,.13,.31),'cream',.035)
 for x in [.52,.82]:k.cyl('Power socket',(x,-1.19,.96),.075,.11,'orange',(math.pi/2,0,0))
 k.box('Thermal readout',(1.22,-.58,1.2),(.09,.37,.26),'status',.015)
 for x in [.1,.32,.54,.76,.98]:k.box('Heat sink',(x,-1.2,.47),(.08,.37,.3),'dark',.02)

records=[]
for key,build in [('dew_condenser',condenser),('geothermal_generator',geothermal)]:
 k.reset();build();scene=bpy.context.scene;scene.unit_settings.system='METRIC'
 source=ROOT/'art/blender/buildings'/f'{key}.blend';model=ROOT/'우주-비즈니스/assets/models'/f'{key}.glb'
 bpy.ops.wm.save_as_mainfile(filepath=str(source))
 editable=sum(o.type=='MESH' for o in scene.objects)
 ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 records.append({'id':key,'source':str(source.relative_to(ROOT)),'model':str(model.relative_to(ROOT)),'editable_meshes':editable,'generator':'tools/build_discovery_industry.py'})
 k.box('Review floor',(0,0,-.14),(100,100,.1),'cream',0)
 scene.world=bpy.data.worlds.new('Discovery industry review');scene.world.color=(.15,.15,.15)
 center=Vector((0,0,1.4));bpy.ops.object.camera_add(location=(7,-10,7));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.8;scene.camera=cam
 for pos,power in [((3,-5,9),1800),((-5,1,7),1200)]:
  bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=6;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=900;scene.render.resolution_y=800;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/f'{key}-blender.png');bpy.ops.render.render(write_still=True)
(ROOT/'art/blender/buildings/discovery_industry.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
