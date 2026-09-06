"""High-detail original accretion flow, lensed rear disk and translucent polar plasma.
Blender meshes/vertex paint are editable; Godot adds time-dependent emission.
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];src=ROOT/'art/blender/galactic-core';out=ROOT/'우주-비즈니스/assets/models/galactic-core';renders=ROOT/'docs/production/media/mineral-galaxy'
for p in (src,out,renders):p.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,paint=False,emission=0,alpha=1):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(.7,.18,.03,alpha);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=1;p.inputs['Specular IOR Level'].default_value=0
 p.inputs['Base Color'].default_value=(0,0,0,1);p.inputs['Emission Strength'].default_value=emission;p.inputs['Alpha'].default_value=alpha
 if paint:
  attr=m.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Flow';m.node_tree.links.new(attr.outputs['Color'],p.inputs['Base Color']);m.node_tree.links.new(attr.outputs['Color'],p.inputs['Emission Color']);m.node_tree.links.new(attr.outputs['Alpha'],p.inputs['Alpha'])
 return m
black=material('event_horizon');disk_mat=material('accretion_flow_vertex_paint',True,2.8,.99);lens_mat=material('lensed_flow_vertex_paint',True,3.2,.99);jet_mat=material('polar_plasma_vertex_paint',True,1.8,.99)
bpy.ops.mesh.primitive_uv_sphere_add(segments=160,ring_count=96,radius=1.18);bpy.context.object.name='Event_horizon';bpy.context.object.data.materials.append(black)
for p in bpy.context.object.data.polygons:p.use_smooth=True

def color(u,v,lens=False):
 a=u*math.tau
 # Differentially wound gas strata: long arcs and uneven hot knots, never solid rings.
 waves=.52+.20*math.sin(v*174+math.sin(a*3+v*17)*1.2)+.13*math.sin(v*411-a*7)+.08*math.sin(a*37+v*290)
 knots=max(0,math.sin(a*11-v*90))**12
 heat=max(0,min(1,(1-v)*.78+waves*.30+knots*.20))
 if heat>.77:
  t=(heat-.77)/.23;c=(1,.55+t*.4,.15+t*.65)
 else:
  t=heat/.77;c=(.22+.78*t,.016+.40*t*t,.004+.07*t*t)
 brightness=(.35+waves*.85)*(.7+.3*math.cos(a+.8))
 fade=min(1,v*24)*max(0,1-v)**.8
 if lens:fade*=.92
 return (*[x*brightness for x in c],fade)

def surface(name,nu,nv,fn,mat,color_fn):
 verts=[];uv=[];colors=[];faces=[]
 for j in range(nv+1):
  v=j/nv
  for i in range(nu+1):
   u=i/nu;verts.append(fn(u,v));uv.append((u,v));colors.append(color_fn(u,v))
 for j in range(nv):
  for i in range(nu):
   n=j*(nu+1)+i;faces.append((n,n+1,n+nu+2,n+nu+1))
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();me.materials.append(mat)
 tex=me.uv_layers.new(name='FlowUV');col=me.color_attributes.new(name='Flow',type='FLOAT_COLOR',domain='CORNER')
 for poly in me.polygons:
  poly.use_smooth=True
  for li in poly.loop_indices:
   vi=me.loops[li].vertex_index;tex.data[li].uv=uv[vi];col.data[li].color=colors[vi]
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);return ob

def disk(u,v):
 a=u*math.tau;r=1.25+v*3.4
 return (math.cos(a)*r,math.sin(a)*r,(math.sin(a*4+v*14)*.028+math.sin(a*11-v*7)*.009)*v)
surface('Accretion_disk',512,192,disk,disk_mat,lambda u,v:color(u,v))
for sign in [1,-1]:
 def lens(u,v,sign=sign):
  a=u*math.pi;r=1.21+v*.76
  return (math.cos(a)*r,.52+v*.2,math.sin(a)*r*sign*(1.08 if sign==1 else .83))
 surface('Lensed_rear_disk_'+str(sign),320,80,lens,lens_mat,lambda u,v:color(u*.5,v,True))
# Soft particle-like sheaths; open ends and alpha taper eliminate pipe caps.
for sign in [-1,1]:
 for layer in range(3):
  def jet(u,v,sign=sign,layer=layer):
   a=u*math.tau;z=sign*(1.20+v*5.8);r=(.025+.06*layer)+v*(.11+.12*layer)
   return (math.cos(a)*r,math.sin(a)*r,z)
  surface('Polar_plasma_%d_%d'%(sign,layer),48,96,jet,jet_mat,lambda u,v,layer=layer:(.18,.48,.95,max(0,math.sin(math.pi*v))*(1-v)**1.8*.18/(layer+1)))
bpy.ops.wm.save_as_mainfile(filepath=str(src/'central_black_hole.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'central_black_hole.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
bpy.ops.object.camera_add(location=(0,-13,2.7));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=12.4;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.use_nodes=True;bg=scene.world.node_tree.nodes.get('Background');bg.inputs['Color'].default_value=(.0003,.0006,.0014,1);bg.inputs['Strength'].default_value=.1
scene.render.filepath=str(renders/'black-hole-blender.png');bpy.ops.render.render(write_still=True)
(src/'manifest.json').write_text(json.dumps({'source':'art/blender/galactic-core/central_black_hole.blend','model':'res://assets/models/galactic-core/central_black_hole.glb','generator':'tools/build_galactic_core.py','style':'original stylized accretion flow; approximate lens silhouette, not ray-traced GR','detail':'512x192 disk, two 320x80 lensed sheets, six fading plasma sheaths'},indent=2)+'\n')
