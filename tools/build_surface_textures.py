"""Original seamless height-field materials, authored and previewed in Blender.
RGBA linear: normal X/Y, height, roughness. Normals derive from the same periodic
height field as the editable preview mesh; no painted-in directional lighting.
"""
from pathlib import Path
import bpy,sys,json,math,hashlib
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as INK
OUT=ROOT/'우주-비즈니스/assets/textures/surfaces';SRC=ROOT/'art/blender/surface-materials';PIC=ROOT/'docs/production/media/planet-surfaces-v2'
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
specs=[('bedrock','746c62',.9),('regolith','927c61',.96),('sand','c6aa7b',.93),('gravel','928b80',.91),('snow','e1e9e7',.82),('ice','709caa',.27),('salt','d9cfab',.75),('lava','534a47',.92),('sediment','ae9475',.91),('crystal','8caba9',.43)]
records=[]
bpy.ops.wm.read_factory_settings(use_empty=True)
for index,(id,tint,rough) in enumerate(specs):
 f=field(813+index);fine=field(201+index,6);dist,edge=cells(160+index,25 if id in ('ice','salt','bedrock') else 58)
 cracks=1-smooth(.0015,.009,edge)
 h=.4+f*.28
 if id=='bedrock':h=.45+f*.22-cracks*.16+smooth(.6,.72,fine)*.10
 elif id=='regolith':h=.35+f*.25+fine*.08
 elif id=='sand':
  ripple=np.sin((u*11+v*2)*math.tau+np.sin(v*math.tau*2)*.8)
  h=.42+f*.13+ripple*.025
 elif id=='gravel':h=.28+np.maximum(0,1-dist/.055)**1.6*.42+f*.12
 elif id=='snow':h=.45+f*.20+np.sin((u*3+v)*math.tau+f*2)*.035
 elif id=='ice':h=.56+f*.08-cracks*.20+(1-smooth(.01,.023,edge))*.035
 elif id=='salt':h=.38+f*.09+(1-cracks)*.12+fine*.03
 elif id=='lava':h=.42+f*.25-cracks*.10-(1-smooth(.007,.024,dist))*.18
 elif id=='sediment':h=.40+f*.18+np.sin((v*7+u)*math.tau+np.sin(u*math.tau*2)*.65)*.075
 elif id=='crystal':h=.38+np.clip(1-dist/.12,0,1)*.25-cracks*.06
 # Metre-scale relief slopes. Restrained INK micro normals, strongest at readable joints.
 amplitude={'bedrock':.035,'regolith':.010,'sand':.012,'gravel':.022,'snow':.014,'ice':.018,'salt':.012,'lava':.026,'sediment':.023,'crystal':.032}[id]
 dx=(np.roll(h,-1,axis=1)-np.roll(h,1,axis=1))*N/8*amplitude
 dy=(np.roll(h,-1,axis=0)-np.roll(h,1,axis=0))*N/8*amplitude
 norm=np.stack([-dx,-dy,np.ones_like(h)],axis=-1);norm/=np.linalg.norm(norm,axis=-1)[...,None]
 rgba=np.stack([norm[...,0]*.5+.5,norm[...,1]*.5+.5,h,np.clip(rough+(f-.5)*.1,0,1)],axis=-1).astype(np.float32)
 image=bpy.data.images.new(id+'_normal_height_rough',width=N,height=N,alpha=True);image.colorspace_settings.name='Non-Color';image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(OUT/(id+'.png'));image.file_format='PNG';image.save();image.pack()
 mat=bpy.data.materials.new('Surface::'+id);mat.use_nodes=True;nd=mat.node_tree.nodes;lk=mat.node_tree.links;bs=nd.get('Principled BSDF')
 tex=nd.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT';sep=nd.new('ShaderNodeSeparateColor');lk.new(tex.outputs['Color'],sep.inputs[0])
 ramp=nd.new('ShaderNodeValToRGB');col=tuple(int(tint[i:i+2],16)/255 for i in (0,2,4));ramp.color_ramp.elements[0].color=(*(x*.50 for x in col),1);ramp.color_ramp.elements[1].color=(*col,1);lk.new(sep.outputs['Blue'],ramp.inputs[0]);lk.new(ramp.outputs[0],bs.inputs['Base Color']);lk.new(tex.outputs['Alpha'],bs.inputs['Roughness'])
 bump=nd.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.42;bump.inputs['Distance'].default_value=amplitude;lk.new(sep.outputs['Blue'],bump.inputs['Height']);lk.new(bump.outputs[0],bs.inputs['Normal'])
 bpy.ops.mesh.primitive_grid_add(x_subdivisions=129,y_subdivisions=129,size=2,location=((index%5)*2.3-4.6,(index//5)*2.4-1.2,0))
 obj=bpy.context.object;obj.name='Editable_'+id
 for vertex in obj.data.vertices:
  ix=int((vertex.co.x+1)*.5*N)%N;iy=int((vertex.co.y+1)*.5*N)%N;vertex.co.z=(float(h[iy,ix])-.5)*amplitude*3
 obj.data.materials.append(mat)
 for poly in obj.data.polygons:poly.use_smooth=True
 records.append({'id':id,'texture':str((OUT/(id+'.png')).relative_to(ROOT)),'sha256':hashlib.sha256((OUT/(id+'.png')).read_bytes()).hexdigest(),'height_amplitude_m':amplitude,'seamless':'periodic Fourier fields and wrapped Voronoi cells'})
# Actual Blender studio render of all ten authored surfaces.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.1));bpy.context.object.data.materials.append(INK.material('structural_dark'))
bpy.ops.object.camera_add(location=(0,-8,12));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=12.5
scene=bpy.context.scene;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-4,-3,7));bpy.context.object.data.energy=1800;bpy.context.object.data.size=5
scene.world=bpy.data.worlds.new('Surface review');scene.world.color=(.17,.19,.22)
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1400;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(PIC/'blender-materials.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'surface-library.blend'));bpy.ops.render.render(write_still=True)
(SRC/'manifest.json').write_text(json.dumps({'version':1,'blender':bpy.app.version_string,'resolution':N,'channels':'linear normal XY / height / roughness','materials':records},ensure_ascii=False,indent=2)+'\n')
print('SURFACE_TEXTURES_COMPLETE',len(records),flush=True)
