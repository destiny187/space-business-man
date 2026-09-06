"""Blender originals for the bold-ink art direction study; Z-up -> Godot Y-up."""
from pathlib import Path
import bpy, math, random, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/ink-study'; OUTPUT=ROOT/'우주-비즈니스/assets/models/ink-study'
SOURCE.mkdir(parents=True,exist_ok=True);OUTPUT.mkdir(parents=True,exist_ok=True)
random.seed(6307)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,c,metal=0,rough=.5):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
P={'cream':material('Ceramic enamel',(.70,.73,.60),.12),'orange':material('Safety ochre',(.9,.29,.035),.22),'dark':material('Ink structural',(.012,.02,.024),.15),'metal':material('Brushed steel',(.23,.34,.37),.65,.25),'teal':material('Lagoon coating',(.02,.22,.22),.3),'glass':material('Optical glass',(.015,.075,.12),.55,.16),'stone':material('Basalt',(.12,.14,.19)),'ore':material('Crystal turquoise',(.025,.51,.52),.48,.22),'ore2':material('Crystal blue',(.02,.27,.35),.5,.25),'gold':material('Copper seam',(.83,.34,.065),.5),'leaf':material('Leaf olive',(.19,.37,.065)),'tip':material('Leaf chartreuse',(.34,.51,.095))}
def finish(o,n,m,b=0,smooth=True):
 o.name=n;o.data.materials.append(P[m]);
 if b:
  mod=o.modifiers.new('Rounded machined edge','BEVEL');mod.width=b;mod.segments=4;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 for f in o.data.polygons:f.use_smooth=smooth
 return o
def box(n,p,s,m,b=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,n,m,b)
def cyl(n,p,r,d,m,rot=(0,0,0),v=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=d,location=p,rotation=rot);return finish(bpy.context.object,n,m,min(.025,d*.2))
def curve(n,pts,r,m):
 c=bpy.data.curves.new(n,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=3;s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for b,p in zip(s.bezier_points,pts):b.co=p;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(n,c);bpy.context.collection.objects.link(o);o.data.materials.append(P[m]);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return o
def label(body,p,size,m):
 bpy.ops.object.text_add(location=p,rotation=(math.pi/2,0,0));o=bpy.context.object;o.data.body=body;o.data.align_x='CENTER';o.data.size=size;o.data.extrude=.001;o.data.materials.append(P[m]);bpy.ops.object.convert(target='MESH');o.name='Marking '+body
manifest={}
def export(name):
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  groups.setdefault(o.data.materials[0].name,[]).append(o)
 for group in groups.values():
  if len(group)==1:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join()
 bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(name+'.glb')),export_format='GLB',export_yup=True)
 tris=0
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
 manifest[name]={'source':str((SOURCE/(name+'.blend')).relative_to(ROOT)),'output':str((OUTPUT/(name+'.glb')).relative_to(ROOT)),'triangles':tris}
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# One extractable mineral deposit: articulated prisms on an eroded host rock.
host_rocks=[]
for p,s in [((0,0,.2),(1.2,.9,.45)),((-.65,.2,.35),(.65,.6,.5)),((.65,.15,.25),(.6,.65,.4))]:
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=p);o=bpy.context.object
 for v in o.data.vertices:v.co*=1+.09*math.sin(v.co.x*8+v.co.y*5+v.co.z*6)
 o.scale=s;finish(o,'Weathered host rock','stone');host_rocks.append(o)
for i,(x,y,h,r) in enumerate([(-.22,.05,2.25,.37),(.40,.10,1.68,.30),(-.72,.02,1.20,.23),(.14,-.48,1.03,.24),(.79,.26,.88,.2),(-.53,.62,1.37,.24)]):
 verts=[];faces=[]
 for z,rad in [(0,r*.85),(h*.79,r),(h,.015)]:
  for j in range(6):a=j*math.tau/6;verts.append((math.cos(a)*rad,math.sin(a)*rad,z))
 for k in range(2):
  for j in range(6):faces.append((k*6+j,k*6+(j+1)%6,(k+1)*6+(j+1)%6,(k+1)*6+j))
 faces.append(tuple(reversed(range(6))));mesh=bpy.data.meshes.new('Hexagonal crystal');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Prismatic mineral',mesh);bpy.context.collection.objects.link(o);o.location=(x,y,.23);o.rotation_euler=(random.uniform(-.12,.12),random.uniform(-.24,.24),i*.4);finish(o,o.name,'ore' if i%2 else 'ore2',.012,False)
bpy.context.view_layer.update()
for path in [[(-1,-.3),(-.6,-.58),(-.18,-.72),(.25,-.63)],[(.5,-.51),(.83,-.15),(1,.22)]]:
 pts=[]
 for a,b in zip(path,path[1:]):
  for step in range(7):
   if pts and step == 0:continue
   t=step/6;x=a[0]*(1-t)+b[0]*t;y=a[1]*(1-t)+b[1]*t;top=-10
   for host in host_rocks:
    inv=host.matrix_world.inverted();hit,p,normal,face=host.ray_cast(inv@Vector((x,y,10)),Vector((0,0,-1)))
    if hit:top=max(top,(host.matrix_world@p).z)
   if top>-9:pts.append((x,y,top+.015))
 verts=[];faces=[]
 for j,point in enumerate(pts):
  tangent=Vector(pts[min(j+1,len(pts)-1)])-Vector(pts[max(j-1,0)])
  side=Vector((-tangent.y,tangent.x,0)).normalized()*.036
  for sign in [-1,1]:
   p=Vector(point)+side*sign;top=-10
   for host in host_rocks:
    inv=host.matrix_world.inverted();hit,hit_point,normal,face=host.ray_cast(inv@Vector((p.x,p.y,10)),Vector((0,0,-1)))
    if hit:top=max(top,(host.matrix_world@hit_point).z)
   p.z=top+.008 if top>-9 else point[2];verts.append(tuple(p))
 for j in range(len(pts)-1):n=j*2;faces.append((n,n+1,n+3,n+2))
 mesh=bpy.data.meshes.new('Surface mineral seam');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Exposed copper vein',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,'gold')
export('mineral_deposit')
# One grass tussock with broad tapered blades, real thickness and central veins.
for i in range(15):
 a=i*2.39996;h=random.uniform(.7,1.55);reach=random.uniform(.45,.98);w=random.uniform(.10,.17);verts=[];faces=[];vein=[];ox=math.cos(a)*random.uniform(.03,.16);oy=math.sin(a)*random.uniform(.03,.16)
 for j in range(17):
  t=j/16;rad=reach*t*t;z=h*(t-.44*t*t);width=math.sin(math.pi*t)**.72*w
  center=Vector((ox+math.cos(a)*rad,oy+math.sin(a)*rad,z));ridge=.023*math.sin(math.pi*t)
  for side in [-1,0,1]:verts.append(tuple(center+Vector((-math.sin(a)*width*side,math.cos(a)*width*side,ridge*(1-abs(side))))))
  if j in [1,4,8,12,15]:vein.append(tuple(center+Vector((0,0,ridge+.007))))
 for j in range(16):
  for k in range(2):n=j*3+k;faces.append((n,n+1,n+4,n+3))
 mesh=bpy.data.meshes.new('Arched leaf');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Broad grass blade',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,'leaf' if i%3 else 'tip');mod=o.modifiers.new('Leaf thickness','SOLIDIFY');mod.thickness=.018
 curve('Drawn central leaf vein',vein,.004,'dark')
export('frontier_grass')
# One building: walk-in mineral processing workshop, with architectural scale.
box('Foundation',(0,0,.17),(5.6,4.3,.34),'dark',.14)
box('Concrete slab',(0,0,.37),(5.3,4.0,.18),'metal',.08)
box('Ceramic envelope',(0,0,1.91),(4.8,3.5,3.05),'cream',.21)
box('Roof shadow line',(0,0,3.43),(4.96,3.66,.18),'dark',.08)
box('Roof safety lip',(0,0,3.59),(5.12,3.82,.19),'orange',.09)
box('Inset roof deck',(0,0,3.70),(4.80,3.50,.055),'teal',.06)
for x in [-2.24,2.24]:
 box('Corner armored pilaster',(x,-1.81,1.85),(.23,.20,2.85),'teal',.08)
 for z in [.65,2.97]:cyl('Anchored fastener',(x,-1.928,z),.058,.035,'metal',(math.pi/2,0,0),6)
# Dark door reveals and two inset sliding plates.
box('Door frame',(-.70,-1.82,1.59),(1.80,.21,2.35),'dark',.09)
for x in [-1.115,-.285]:
 box('Sliding access leaf',(x,-1.948,1.58),(.78,.06,2.20),'teal',.045)
 box('Door window',(x,-1.99,1.99),(.59,.027,.53),'glass',.035)
box('Door seam',(-.70,-1.996,1.57),(.035,.018,2.11),'dark',.005)
for x in [-.88,-.51]:box('Door handle',(x,-2.025,1.47),(.035,.055,.22),'metal',.014)
box('Threshold',(-.70,-2.0,.49),(2.15,.52,.12),'metal',.04)
box('Entry step',(-.70,-2.31,.23),(2.37,.62,.25),'cream',.06)
box('Canopy',(-.70,-2.02,2.90),(2.27,.72,.18),'orange',.06)
# Inspectable window, service panel and external routing.
box('Front window gasket',(1.04,-1.796,2.10),(1.36,.12,.90),'dark',.07)
box('Front window',(1.04,-1.865,2.10),(1.20,.035,.75),'glass',.04)
for x in [.64,1.44]:box('Window mullion',(x,-1.893,2.10),(.043,.023,.80),'cream',.012)
box('Utility access',(1.06,-1.80,1.05),(1.21,.15,.65),'orange',.05)
for z in [.89,1.03,1.17]:box('Panel intake',(1.06,-1.887,z),(.85,.02,.055),'dark',.01)
label('LOCUS / REFINERY',(0,-1.784,3.14),.23,'dark')
label('ORE   /   01',(1.05,-1.89,1.47),.115,'dark')
# Side facade has inset panel seams and a heat exchanger.
for y in [-1.0,0,1.0]:box('Side panel seam',(2.407,y,1.91),(.018,.028,2.3),'dark',.004)
box('Heat exchanger',(2.47,.38,1.79),(.25,1.52,1.66),'teal',.10)
for z in [1.15+i*.17 for i in range(8)]:box('Radiator louvre',(2.62,.38,z),(.04,1.25,.065),'dark',.017)
curve('External plumbing',[(2.60,-.8,.60),(2.75,-.8,.77),(2.75,-.8,2.70),(2.5,-.8,2.9)],.058,'metal')
# Roof equipment, collar seams and hooded stacks.
box('Roof compressor',(-.83,.35,4.05),(1.65,1.32,.65),'teal',.14)
for x in [-1.35,-1.08,-.81,-.54,-.27]:box('Compressor rib',(x,.35,4.385),(.08,1.10,.04),'dark',.02)
for x,y,h in [(1.1,.55,1.24),(1.60,-.20,.82)]:
 cyl('Vent stack',(x,y,3.70+h*.5),.23,h,'metal')
 for z in [3.85,3.70+h-.1]:cyl('Stack collar',(x,y,z),.28,.09,'dark')
 cyl('Rain hood',(x,y,3.73+h),.34,.13,'orange')
for x in [-2,2]:
 for y in [-1.53,1.53]:cyl('Roof tie',(x,y,3.755),.055,.06,'dark',v=6)
export('ore_refinery')
(SOURCE/'manifest.json').write_text(json.dumps({'generator':'tools/build_ink_samples.py','assets':manifest},indent=2))
print('INK_MODELS_COMPLETE',json.dumps(manifest))
