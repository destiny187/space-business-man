"""Authored active-mission hardware. Editable Blender sources, functional pivots, INK exports."""
import math, sys, random
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
SRC=ROOT/'art/blender/incidents';OUT=ROOT/'우주-비즈니스/assets/models/incidents';REVIEW=ROOT/'output/active-missions'
for p in (SRC,OUT,REVIEW):p.mkdir(parents=True,exist_ok=True)
def material(role):return ink.material(role)
def parent(o,p):
 if p:o.parent=p;o.matrix_parent_inverse=p.matrix_world.inverted()
 return o
def empty(name,at=(0,0,0),p=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=at;bpy.context.view_layer.update();return parent(o,p)
def box(name,at,size,role='enamel_cream',p=None,bevel=.05):
 bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material(role));ink.manufactured_edges(o,bevel,3);return parent(o,p)
def rod(name,a,b,r,role='edge_steel',p=None):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=(b-a).length,location=(a+b)*.5);o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(material(role));ink.manufactured_edges(o,.02,3);return parent(o,p)
def rock(name,at,size,p=None):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=at);o=bpy.context.object;o.name=name;o.scale=size
 mat=bpy.data.materials.get('Mission basalt')
 if not mat:mat=bpy.data.materials.new('Mission basalt');mat.diffuse_color=(.17,.19,.20,1);mat.use_nodes=True;mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=mat.diffuse_color;mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92
 o.data.materials.append(mat);return parent(o,p)
def case(p,at=(0,0,0),scale=1):
 x,y,z=at;box('Pressure case',(x,y,z+.38*scale),(1.25*scale,.85*scale,.76*scale),'enamel_teal',p,.09)
 box('Sealed lid',(x,y,z+.8*scale),(1.29*scale,.89*scale,.13*scale),'enamel_cream',p)
 for s in [-1,1]:box('Latch',(x+s*.42*scale,y-.46*scale,z+.58*scale),(.14*scale,.08*scale,.25*scale),'safety_orange',p,.025)
 rod('Handle',(x-.2*scale,y,z+.92*scale),(x+.2*scale,y,z+.92*scale),.035*scale,p=p)
def switch(p):
 box('Controller plinth',(0,0,.55),(.8,.65,1.1),'enamel_teal',p)
 box('Control fascia',(0,-.37,.97),(.65,.11,.55),'structural_dark',p)
 lever=empty('Anim_Lever',(0,-.46,.85),p);rod('Disconnect lever',(0,-.46,.85),(0,-.65,1.35),.07,'safety_orange',lever)
 box('Indicator',(0,-.442,1.16),(.26,.05,.08),'safety_orange',p,.015)
 for s in [-1,1]:rod('Cable gland',(s*.24,0,.1),(s*.24,0,.35),.08,p=p)
def vehicle(p,rover=False):
 box('Chassis',(0,0,.55),(2.3,3.6,.35),'structural_dark',p,.13)
 box('Axle deck',(0,0,.92),(2.35,3.3,.38),'enamel_teal',p,.13)
 for y in [-1.25,0,1.25]:
  rod('Axle',(-1.28,y,.5),(1.28,y,.5),.1,p=p)
  for s in [-1,1]:
   w=empty('Anim_Wheel_'+str(y)+'_'+str(s),(s*1.25,y,.55),p)
   rod('Tyre',(s*1.10,y,.55),(s*1.4,y,.55),.52,'rubber',w)
   rod('Wheel hub',(s*1.4,y,.55),(s*1.44,y,.55),.27,'enamel_cream',w)
   box('Hub marker',(s*1.46,y,.73),(.02,.11,.24),'safety_orange',w,.01)
   rod('Suspension',(s*.83,y,.94),(s*1.16,y,.55),.085,'edge_steel',p)
 box('Sloped nose',(0,1.68,1.22),(1.85,.48,.5),'enamel_cream',p,.18)
 for s in [-1,1]:box('Headlamp',(s*.64,1.94,1.29),(.3,.07,.14),'safety_orange',p,.025)
 if rover:
  box('Survey equipment',(0,-.5,1.37),(1.75,1.75,.57),'enamel_cream',p,.16)
  mast=empty('Anim_Mast',(0,-.4,1.65),p);rod('Sensor mast',(0,-.4,1.6),(0,-.4,2.65),.07,p=mast)
  box('Stereo camera',(0,-.4,2.62),(.95,.35,.25),'enamel_teal',mast)
  for s in [-1,1]:rod('Sensor lens',(s*.32,-.18,2.62),(s*.32,-.1,2.62),.095,'structural_dark',mast)
  case(p,(0,.9,1.45),.5)
 else:
  box('Cargo cradle',(0,-.1,1.27),(2,2.55,.26),'edge_steel',p)
  payload=empty('Anim_Payload',p=p);case(payload,(0,-.35,1.38),1.3)
  for s in [-1,1]:box('Cargo rail',(s*.99,-.25,1.75),(.09,2.65,.65),'enamel_cream',p)
 # Exposed side drive assembly matches the host damage volume.
 box('Exposed drive casing',(1.25,0,.75),(.4,1.95,.48),'safety_orange',p,.08)
 for y in [-.65,0,.65]:rod('Drive bearing',(1.46,y,.75),(1.51,y,.75),.13,'structural_dark',p)
def build(id):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 p=empty(id)
 if id=='mission_relay':
  box('Broad footing',(0,0,.12),(1.8,1.6,.24),'structural_dark',p)
  rod('Mast',(0,0,.2),(0,0,2),.14,'enamel_cream',p)
  for s in [-1,1]:rod('Mast brace',(s*.7,0,.22),(0,0,1.25),.07,'edge_steel',p)
  pivot=empty('Anim_Dish',(0,0,2.1),p)
  # Concave dish, facing Blender +Y (Godot -Z).
  verts=[];faces=[];rings=7;n=48
  for j in range(rings):
   r=.04+j*.12
   for i in range(n):
    a=math.tau*i/n;verts.append((math.cos(a)*r,.23*r*r,2.1+math.sin(a)*r))
  for j in range(rings-1):
   for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
  mesh=bpy.data.meshes.new('Reflector bowl');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Reflector bowl',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(material('enamel_cream'));parent(o,pivot)
  sol=o.modifiers.new('Reflector thickness','SOLIDIFY');sol.thickness=.035
  for x,z in [(-.55,2.1),(.55,2.1),(0,2.7)]:rod('Feed support',(x,.06,z),(0,.55,2.1),.026,'edge_steel',pivot)
  rod('Feed horn',(0,.45,2.1),(0,.68,2.1),.095,'safety_orange',pivot)
  box('Control dial',(0,-.9,1.1),(.65,.3,.38),'enamel_teal',p)
 elif id=='mission_platform':
  box('Landing deck',(0,0,-.14),(5.5,5.5,.28),'structural_dark',p,.08)
  for s in [-1,1]:
   box('Landing edge',(s*2.64,0,.05),(.12,5.4,.1),'safety_orange',p,.02)
   rod('Safety post',(s*2.55,2.55,0),(s*2.55,2.55,.8),.045,p=p)
  for y in [-1.8,-.9,0,.9,1.8]:box('Gripping strip',(0,y,.017),(4.6,.12,.035),'edge_steel',p,.012)
 elif id=='mission_bluff':
  random.seed(10)
  vertices=[];faces=[];sides=12
  levels=[(0,3.2),(.3,3.5),(1.4,3.1),(1.55,2.8),(2.5,2.9),(2.65,2.5),(3.8,2.7),(3.95,2.35),(5.1,2.5),(5.25,2.25),(6,2.3)]
  for layer,(z,radius) in enumerate(levels):
   for j in range(sides):
    a=2*math.pi*j/sides;radius_j=radius*(1+.10*math.sin(j*4.7))
    vertices.append((math.cos(a)*radius_j+.16*math.sin(layer),math.sin(a)*radius_j,z))
  for layer in range(len(levels)-1):
   for j in range(sides):faces.append((layer*sides+j,layer*sides+(j+1)%sides,(layer+1)*sides+(j+1)%sides,(layer+1)*sides+j))
  faces.extend([tuple(reversed(range(sides))),tuple((len(levels)-1)*sides+j for j in range(sides))])
  mesh=bpy.data.meshes.new('Layered basalt');mesh.from_pydata(vertices,[],faces);mesh.update()
  o=bpy.data.objects.new('Weathered stratified bluff',mesh);bpy.context.collection.objects.link(o);parent(o,p)
  for shade in [.16,.19,.22]:
   mat=bpy.data.materials.new('Basalt stratum');mat.diffuse_color=(shade,shade*1.08,shade*1.12,1);mat.use_nodes=True;mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=mat.diffuse_color;mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92;mesh.materials.append(mat)
  for face in mesh.polygons:face.material_index=(face.index//sides)%3
 elif id in ['mission_convoy','mission_rover']:vehicle(p,id=='mission_rover')
 elif id=='mission_switch':switch(p)
 elif id=='mission_sensor':
  rock('Basalt perch',(0,0,.9),(2.4,2.1,1.05),p);case(p,(0,0,1.85),.65)
  rod('Broken sensor boom',(-.9,.1,1.65),(-.5,.1,2.55),.06,'enamel_cream',p)
 elif id=='mission_blocker':
  for i in range(4):rock('Route rubble',((i%2-.5)*1.2,(i//2-.5)*.8,.55),(1,.8,.8),p)
 elif id=='mission_vent':
  for i in range(7):
   a=i*math.tau/7;rock('Vented basalt',(math.cos(a)*1.15,math.sin(a)*1.15,.28),(.7,.7,.45),p)
  gem=empty('Anim_Crystal',p=p)
  for i in range(4):
   bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.19,radius2=.07,depth=.8+i*.15,location=((i%2-.5)*.45,(i//2-.5)*.45,.7))
   o=bpy.context.object;o.name='Crystal prism';mat=bpy.data.materials.get('Mission sapphire')
   if not mat:mat=bpy.data.materials.new('Mission sapphire');mat.diffuse_color=(.06,.25,.55,1)
   o.data.materials.append(mat);parent(o,gem)
 elif id=='mission_vault':
  box('Vault deck',(0,0,.1),(8,10,.2),'structural_dark',p)
  for s in [-1,1]:
   box('Armored wall',(s*3.8,0,2.4),(.4,10,4.8),'enamel_teal',p,.12)
   for y in [-4,-1,2,4]:box('Hull buttress',(s*3.95,y,2),(.5,.55,4),'enamel_cream',p,.08)
  box('Vault roof',(0,0,4.7),(8.2,10.2,.28),'enamel_cream',p)
  box('Back wall',(0,4.8,2.4),(8,.4,4.8),'enamel_teal',p)
  for s in [-1,1]:box('Entrance pier',(s*2.9,-4.8,2.4),(2.2,.45,4.8),'enamel_cream',p)
  gate=empty('Anim_Gate',(0,-4.8,0),p);box('Pressure shutter',(0,-4.8,2.25),(3.55,.25,4.4),'structural_dark',gate)
  for x in [-1.3,1.3]:box('Door locking bar',(x,-4.99,2.25),(.16,.12,4.2),'safety_orange',gate)
  for y in [-4,-2,0,2,4]:box('Floor strip',(0,y,.22),(3.2,.08,.04),'edge_steel',p,.01)
  payload=empty('Anim_Payload',p=p);case(payload,(0,3,.24),1)
 elif id=='mission_lander':
  box('Cargo fuselage',(0,0,3.1),(7,11,3.7),'enamel_cream',p,.6)
  box('Lower cargo spine',(0,0,1.7),(6.2,10,.55),'enamel_teal',p,.16)
  box('Cockpit',(0,5,3.5),(4.8,3,2.5),'enamel_teal',p,.7)
  box('Forward glazing',(0,6.51,3.7),(3.8,.1,1.1),'structural_dark',p,.25)
  for s in [-1,1]:
   rod('Engine nacelle',(s*4,-3,2.9),(s*4,1.5,2.9),1,'enamel_teal',p)
   rod('Nozzle',(s*4,-3.4,2.9),(s*4,-3,2.9),.75,'structural_dark',p)
   for y in [-3,3]:
    rod('Landing strut',(s*2.5,y,1.9),(s*3.5,y,0.5),.16,'edge_steel',p)
    box('Landing pad',(s*3.5,y,.3),(1.6,1.8,.25),'structural_dark',p)
  case(p,(0,-6,0),1)
 return p
ids=['mission_relay','mission_platform','mission_bluff','mission_convoy','mission_rover','mission_switch','mission_sensor','mission_blocker','mission_vent','mission_vault','mission_lander']
if '--' in sys.argv:ids=sys.argv[sys.argv.index('--')+1:]
for id in ids:
 build(id);bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(id+'.blend')));ink.consolidate_static_surfaces();bpy.ops.export_scene.gltf(filepath=str(OUT/(id+'.glb')),export_format='GLB',export_yup=True)
 # Source silhouette/contact-sheet tiles are real Cycles renders.
 size=18 if id=='mission_lander' else 15 if id=='mission_vault' else 11 if id=='mission_bluff' else 7 if id=='mission_platform' else 6
 bpy.ops.object.camera_add(location=(size*.8,-size, size*.75));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,3 if id=='mission_bluff' else 1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size;bpy.context.scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(3,-4,8));bpy.context.object.data.energy=1500;bpy.context.object.data.size=7
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.world.color=(.22,.22,.22);scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/(id+'-blender.png'));bpy.ops.render.render(write_still=True)
print('ACTIVE_MISSION_ASSETS',len(ids))
