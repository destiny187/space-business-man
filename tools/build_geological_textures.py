"""Seven distinct geological packed surfaces, authored and previewed in Blender.
RGBA linear: normal X/Y, height, roughness. Normals derive from the same periodic
height field as the editable preview mesh; no painted-in directional lighting.
"""
from pathlib import Path
import bpy,sys,json,math,hashlib
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as INK
OUT=ROOT/'우주-비즈니스/assets/textures/surfaces';SRC=ROOT/'art/blender/surface-materials';PIC=ROOT/'docs/production/media/planet-variety'
for p in [OUT,SRC,PIC]:p.mkdir(parents=True,exist_ok=True)
N=1024
u,v=np.meshgrid((np.arange(N)+.5)/N,(np.arange(N)+.5)/N)
def smooth(lo,hi,x):
 t=np.clip((x-lo)/(hi-lo),0,1);return t*t*(3-2*t)
def field(seed,octaves=4):
 rng=np.random.default_rng(seed);a=np.zeros((N,N))
 for octave in range(octaves):
  for k in range(5):
   freq=2**octave;fx=int(rng.integers(1,4))*freq;fy=int(rng.integers(-3,4))*freq
   a+=np.sin((u*fx+v*fy)*math.tau+rng.uniform(0,math.tau))*(.55**octave)/5
 return .5+a*.4
def cells(seed,count=32):
 rng=np.random.default_rng(seed);first=np.full((N,N),9.);second=first.copy()
 for x,y in rng.random((count,2)):
  dx=np.minimum(abs(u-x),1-abs(u-x));dy=np.minimum(abs(v-y),1-abs(v-y));d=np.sqrt(dx*dx+dy*dy)
  second=np.minimum(second,np.maximum(first,d));first=np.minimum(first,d)
 return first,second-first
specs=[('basalt_columns','646672',.91),('porous_tuff','a78d70',.98),('sandstone_bedded','ae8060',.93),('frost_fracture','97b1be',.65),('salt_polygons','c8c0a6',.89),('impact_breccia','928780',.94),('folded_slate','718286',.87)]
records=[]
bpy.ops.wm.read_factory_settings(use_empty=True)
for index,(id,tint,rough) in enumerate(specs):
 f=field(761+index);fine=field(491+index,5)
 dist,edge=cells(207+index,20 if id in ('basalt_columns','salt_polygons') else 45)
 cracks=1-smooth(.002,.012,edge)
 if id=='basalt_columns':h=.34+smooth(.003,.030,edge)*.26+f*.08
 elif id=='porous_tuff':h=.52+f*.10-(1-smooth(.006,.028,dist))*.28+fine*.03
 elif id=='sandstone_bedded':
  layers=(v*7+np.sin(u*math.tau)*.13+f*.14)%1
  h=.31+smooth(.05,.80,layers)*.27-cracks*.045+fine*.045
 elif id=='frost_fracture':
  shear=abs(np.sin((u*3+v)*math.tau+np.sin(v*math.tau*2)*.35))
  h=.52+f*.10-(1-smooth(.02,.15,shear))*.23-cracks*.035
 elif id=='salt_polygons':h=.37+f*.08+smooth(.002,.007,edge)*(1-smooth(.007,.024,edge))*.18+smooth(.012,.045,edge)*.045
 elif id=='impact_breccia':h=.30+np.clip(1-dist/.11,0,1)*.42-cracks*.12+fine*.055
 elif id=='folded_slate':
  folds=np.sin((u*4+v*7)*math.tau+np.sin((u-v)*math.tau*2)*1.5)
  h=.36+smooth(-.5,.7,folds)*.20+f*.07-cracks*.035
 amplitude={'basalt_columns':.11,'porous_tuff':.09,'sandstone_bedded':.085,'frost_fracture':.08,'salt_polygons':.08,'impact_breccia':.11,'folded_slate':.075}[id]
 dx=(np.roll(h,-1,axis=1)-np.roll(h,1,axis=1))*N/8*amplitude
 dy=(np.roll(h,-1,axis=0)-np.roll(h,1,axis=0))*N/8*amplitude
 norm=np.stack([-dx,-dy,np.ones_like(h)],axis=-1);norm/=np.linalg.norm(norm,axis=-1)[...,None]
 rgba=np.stack([norm[...,0]*.5+.5,norm[...,1]*.5+.5,h,np.clip(rough+(f-.5)*.1,0,1)],axis=-1).astype(np.float32)
 image=bpy.data.images.new(id+'_normal_height_rough',width=N,height=N,alpha=True);image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(OUT/(id+'.png'));image.file_format='PNG';image.save();image.pack()
 mat=bpy.data.materials.new('Surface::'+id);mat.use_nodes=True;nd=mat.node_tree.nodes;lk=mat.node_tree.links;bs=nd.get('Principled BSDF')
 tex=nd.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT';sep=nd.new('ShaderNodeSeparateColor');lk.new(tex.outputs['Color'],sep.inputs[0])
 ramp=nd.new('ShaderNodeValToRGB');col=tuple(int(tint[i:i+2],16)/255 for i in (0,2,4));ramp.color_ramp.elements[0].color=(*(x*.50 for x in col),1);ramp.color_ramp.elements[1].color=(*col,1);lk.new(sep.outputs['Blue'],ramp.inputs[0]);lk.new(ramp.outputs[0],bs.inputs['Base Color']);lk.new(tex.outputs['Alpha'],bs.inputs['Roughness'])
 bump=nd.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.42;bump.inputs['Distance'].default_value=amplitude;lk.new(sep.outputs['Blue'],bump.inputs['Height']);lk.new(bump.outputs[0],bs.inputs['Normal'])
 bpy.ops.mesh.primitive_grid_add(x_subdivisions=129,y_subdivisions=129,size=2,location=((index%4)*2.3-3.45,(index//4)*2.4-1.2,0))
 obj=bpy.context.object;obj.name='Editable_'+id
 for vertex in obj.data.vertices:
  ix=int((vertex.co.x+1)*.5*N)%N;iy=int((vertex.co.y+1)*.5*N)%N;vertex.co.z=(float(h[iy,ix])-.5)*amplitude*3
 obj.data.materials.append(mat)
 for poly in obj.data.polygons:poly.use_smooth=True
 records.append({'id':id,'texture':str((OUT/(id+'.png')).relative_to(ROOT)),'sha256':hashlib.sha256((OUT/(id+'.png')).read_bytes()).hexdigest(),'height_amplitude_m':amplitude,'seamless':'periodic Fourier fields and wrapped Voronoi cells'})
# Actual Blender studio render; game uses the shared INK shader.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.1));bpy.context.object.data.materials.append(INK.material('structural_dark'))
bpy.ops.object.camera_add(location=(0,-8,12));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10.5
scene=bpy.context.scene;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-4,-3,7));bpy.context.object.data.energy=1800;bpy.context.object.data.size=5
scene.world=bpy.data.worlds.new('Surface review');scene.world.color=(.17,.19,.22)
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1400;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(PIC/'blender-geology.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'geological-variety.blend'));bpy.ops.render.render(write_still=True)
(SRC/'geological-variety.json').write_text(json.dumps({'version':1,'blender':bpy.app.version_string,'resolution':N,'channels':'linear normal XY / height / roughness','materials':records},ensure_ascii=False,indent=2)+'\n')
print('GEOLOGICAL_TEXTURES_COMPLETE',len(records),flush=True)
