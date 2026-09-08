"""Author the four-wheel SCOUT rover in Blender; +Y forward, Z up, metres.
Independent steering, suspension, wheel, door, cargo and lashing nodes survive GLB export.
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/blender/vehicles';OUT.mkdir(parents=True,exist_ok=True)
GAME=ROOT/'우주-비즈니스/assets/models/vehicles';GAME.mkdir(parents=True,exist_ok=True)
REVIEW=ROOT/'docs/production/media/rover';REVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.5,alpha=1,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,alpha);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,alpha);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Alpha'].default_value=alpha
 if alpha<1:m.surface_render_method='DITHERED';m.use_transparency_overlap=False
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
cream=mat('Ceramic enamel ivory',(.82,.79,.66),.25,.34)
teal=mat('Ceramic enamel lagoon',(.045,.38,.37),.3,.34)
orange=mat('Service ochre',(.96,.35,.055),.15)
dark=mat('Graphite chassis',(.028,.045,.055),.55)
rubber=mat('Soft graphite tyre',(.035,.039,.041),0,.9)
steel=mat('Edge steel machined',(.36,.44,.46),.8,.27)
glass=mat('Pressure glazing',(.12,.32,.36),.05,.18,.18)
light=mat('Headlight warm',(.96,.9,.64),0,.4,emission=1.5)
red=mat('Rear signal',(.7,.07,.035),0,.4,emission=.5)
screen=mat('Instrument mint',(.14,.68,.55),.1,.35,emission=.5)
def parent(ob,p):
 if p:bpy.context.view_layer.update();ob.parent=p;ob.matrix_parent_inverse=p.matrix_world.inverted()
 return ob
def empty(name,loc,p=None):
 ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob);ob.location=loc;parent(ob,p);return ob
def finish(ob,name,m,p=None,bevel=0):
 ob.name=name;ob.data.materials.append(m)
 if bevel:
  mod=ob.modifiers.new('Rounded manufactured edge','BEVEL');mod.width=bevel;mod.segments=3
  ob.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
 return parent(ob,p)
def box(name,loc,size,m,p=None,bevel=.035,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);ob=bpy.context.object;ob.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if rot:ob.rotation_euler=rot
 return finish(ob,name,m,p,bevel)
def cylinder(name,a,b,r,m,p=None,vertices=24):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2);ob=bpy.context.object;ob.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for poly in ob.data.polygons:poly.use_smooth=len(poly.vertices)==4
 return finish(ob,name,m,p,.012)
def panel(name,verts,m,p=None):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[list(range(len(verts)))]);mesh.update();ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);finish(ob,name,m,p);solid=ob.modifiers.new('Panel thickness','SOLIDIFY');solid.thickness=.024;return ob
root=empty('SCOUT_Rover', (0,0,0))
box('Armoured belly',(0,0,.79),(2.15,3.95,.34),dark,root,.15)
box('Battery cassette',(0,-.18,.60),(1.30,2.60,.25),teal,root,.09)
box('Cabin sill',(0,.25,1.04),(2.28,2.8,.28),cream,root,.10)
# Wraparound front hood, safety bumper and characteristic U-shaped lights.
box('Nose equipment bay',(0,1.62,1.14),(2.20,.72,.42),teal,root,.13)
box('Front bumper',(0,2.05,.84),(2.4,.19,.20),dark,root,.06)
for x in [-.94,.94]:
 box('Headlamp socket',(x,1.99,1.19),(.38,.12,.27),dark,root,.07)
 box('Headlamp',(x,2.065,1.20),(.27,.04,.15),light,root,.04)
 cylinder('Tow eye',(x*.68,2.05,.81),(x*.68,2.20,.81),.07,orange,root)
# Two separate seats, real interior, low dashboard and steering yoke.
for x in [-.57,.57]:
 box('Seat pedestal',(x,.10,1.2),(.52,.62,.22),dark,root)
 box('Seat cushion',(x,.18,1.38),(.63,.66,.16),orange,root,.09)
 box('Seat back',(x,-.10,1.76),(.64,.20,.75),dark,root,.09,(-.10,0,0))
 box('Seat insert',(x,.02,1.79),(.49,.08,.51),teal,root,.045,(-.10,0,0))
 box('Head restraint',(x,-.16,2.23),(.44,.22,.26),orange,root,.07)
 empty('Socket_Seat_Driver' if x<0 else 'Socket_Seat_Passenger',(x,.15,1.38),root)
 empty('Socket_Eye_Driver' if x<0 else 'Socket_Eye_Passenger',(x,.21,2.10),root)
box('Dashboard',(0,1.08,1.52),(2.00,.42,.22),dark,root,.07)
for x in [-.58,.36]:box('Dashboard display',(x,.89,1.64),(.40,.025,.15),screen,root,.012,(-.30,0,0))
cylinder('Steering column',(-.57,.98,1.5),(-.57,.65,1.71),.045,steel,root)
yoke=empty('Anim_SteeringYoke',(-.57,.65,1.71),root)
for x in [-.81,-.33]:box('Yoke grip',(x,.64,1.75),(.07,.09,.23),dark,yoke,.035)
box('Yoke bridge',(-.57,.64,1.68),(.52,.07,.07),steel,yoke)
box('Cabin rear wall',(0,-.70,1.89),(2.15,.16,1.61),cream,root,.08)
box('Roof',(0,.19,2.69),(2.30,2.00,.17),cream,root,.08)
box('Roof rescue stripe',(0,.19,2.785),(.30,1.9,.025),orange,root,.01)
for x in [-1.04,1.04]:
 cylinder('A pillar',(x,1.38,1.40),(x*.94,.99,2.64),.065,cream,root)
 cylinder('B pillar',(x,-.64,1.14),(x,-.64,2.62),.07,dark,root)
 cylinder('Roof grab rail',(x,0,2.83),(x,.60,2.83),.035,steel,root)
panel('Windshield',[(-.98,1.35,1.56),(.98,1.35,1.56),(.96,1.02,2.59),(-.96,1.02,2.59)],glass,root)
cylinder('Windshield divider',(0,1.36,1.56),(0,1.02,2.6),.021,dark,root)
for side,x in [('L',-1.10),('R',1.10)]:
 door=empty('Anim_Door_'+side,(x,1.05,1.6),root)
 box('Door lower '+side,(x,.23,1.45),(.10,1.68,.63),teal,door,.055)
 panel('Side glazing '+side,[(x,.99,1.77),(x,-.58,1.77),(x,-.58,2.57),(x,.74,2.57)],glass,door)
 for y in [-.59,.88]:cylinder('Door frame '+side,(x,y,1.66),(x,y-.1 if y>0 else y,2.60),.038,cream,door)
 cylinder('Window belt '+side,(x,-.58,1.75),(x,1,1.75),.036,cream,door)
 cylinder('Door window top '+side,(x,-.58,2.59),(x,.77,2.59),.035,cream,door)
 box('Door latch '+side,(x*1.07,-.33,1.61),(.065,.25,.055),orange,door,.02)
 box('Foot step '+side,(x*1.14,.10,.91),(.39,.72,.09),steel,root,.035)
 empty('Socket_Door_'+side,(x*1.28,.1,0),root)
# Cargo deck is visibly separate, with four recessed modular cells and a hinged lid.
box('Cargo tub',(0,-1.43,1.14),(2.10,1.24,.54),teal,root,.07)
for x in [-.48,.48]:
 for y in [-1.14,-1.70]:box('Cargo slot',(x,y,1.44),(.88,.47,.08),dark,root,.035)
lid=empty('Anim_CargoLid',(0,-.82,1.46),root)
box('Cargo lid',(0,-1.45,1.53),(2.13,1.28,.12),cream,lid,.045)
for x in [-.84,.84]:box('Cargo latch',(x,-2.08,1.46),(.18,.06,.19),orange,lid,.025)
empty('Socket_Cargo',(0,-2.16,1.30),root)
for x in [-.96,.96]:
 box('Rear stop lamp',(x,-2.09,1.12),(.17,.07,.23),red,root,.025)
 cylinder('Lashing anchor',(x,-1.98,.79),(x,-2.12,.79),.08,orange,root)
 empty('Socket_Lash_'+str(x),(x,-1.95,.86),root)
box('Rear bumper',(0,-2.12,.78),(2.38,.18,.16),dark,root,.05)
for i in range(5):box('Cooling vent',(1.085,-1.45+(i-2)*.15,1.19),(.035,.065,.26),dark,root,.014)
cylinder('Antenna mast',(.82,-.66,2.64),(.82,-.66,3.21),.021,steel,root)
# Each wheel has separate suspension -> steering -> rolling transform.
for side,x in [('L',-1.34),('R',1.34)]:
 for end,y in [('F',1.35),('B',-1.35)]:
  key=side+end;susp=empty('Anim_Suspension_'+key,(x,y,.70),root);steer=empty('Anim_Steer_'+key,(x,y,.70),susp);wheel=empty('Anim_Wheel_'+key,(x,y,.70),steer)
  cylinder('Wishbone '+key,(x*.48,y,.75),(x,y,.70),.065,dark,susp)
  cylinder('Damper barrel '+key,(x*.78,y,.92),(x*.85,y,1.30),.085,orange,root)
  cylinder('Damper rod '+key,(x*.85,y,.64),(x*.85,y,1.21),.035,steel,susp)
  bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=12,major_radius=.50,minor_radius=.19,location=(x,y,.70),rotation=(0,math.pi/2,0));ob=bpy.context.object
  for poly in ob.data.polygons:poly.use_smooth=True
  finish(ob,'Tyre '+key,rubber,wheel)
  cylinder('Wheel dish '+key,(x-.19,y,.70),(x+.19,y,.70),.46,dark,wheel,32)
  outer=x+(-.205 if x<0 else .205)
  cylinder('Rim '+key,(outer-.015,y,.7),(outer+.015,y,.7),.34,steel,wheel,32)
  cylinder('Hub '+key,(outer-.035,y,.7),(outer+.035,y,.7),.15,teal,wheel)
  for k in range(24):
   angle=k*math.tau/24;yy=y+math.sin(angle)*.68;zz=.70+math.cos(angle)*.68
   box('Tread '+key,(x,yy,zz),(.34,.11,.055),rubber,wheel,.016,(-angle,0,0))
  for k in range(6):
   angle=k*math.tau/6;yy=y+math.sin(angle)*.24;zz=.70+math.cos(angle)*.24
   cylinder('Lug '+key,(outer-.025,yy,zz),(outer+.025,yy,zz),.029,dark,wheel,12)
  box('Fender '+key,(x*.89,y,1.48),(.66,1.08,.12),cream,root,.065)
# Save before export and render. Cameras/lights are review-only, excluded from the GLB.
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'scout_rover.blend'))
bpy.ops.export_scene.gltf(filepath=str(GAME/'scout_rover.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
scene=bpy.context.scene;scene.world.color=(.16,.16,.16)
box('Review floor',(0,0,-.05),(200,200,.08),mat('Review neutral',(.13,.17,.18)))
bpy.ops.object.camera_add(location=(7,9,5.2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.5;scene.camera=cam
for pos,energy,size in [((4,5,8),1700,5),((-5,2,4),1100,5),((0,-5,7),1700,4)]:
 bpy.ops.object.light_add(type='AREA',location=pos);ob=bpy.context.object;ob.data.energy=energy;ob.data.shape='DISK';ob.data.size=size;ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/'scout-blender.png');bpy.ops.render.render(write_still=True)
record={'version':1,'generator':'tools/build_scout_rover.py','source':'art/blender/vehicles/scout_rover.blend','game_file':'우주-비즈니스/assets/models/vehicles/scout_rover.glb','nodes':[ob.name for ob in bpy.data.objects if ob.name.startswith(('Anim_','Socket_'))],'geometry':'new-scout-rover','dimensions_metres':[3.1,4.4,3.25],'authoring_forward':'+Y','game_forward':'-Z'}
(OUT/'manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print('SCOUT_ROVER_EXPORTED')
