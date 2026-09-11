"""Eight natural and recovering soil surfaces, authored and previewed in Blender.
RGBA linear: normal X/Y, height, roughness. Normals derive from the same periodic
height field as the editable preview mesh; no painted-in directional lighting.
"""
from pathlib import Path
import bpy,sys,json,math,hashlib
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as INK
OUT=ROOT/'우주-비즈니스/assets/textures/surfaces';SRC=ROOT/'art/blender/surface-materials';PIC=ROOT/'docs/production/media/terraform-surfaces'
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
def cells(seed,count=32,irregular=False):
 rng=np.random.default_rng(seed);first=np.full((N,N),9.);second=first.copy()
 for x,y in rng.random((count,2)):
  dx=(u-x+.5)%1-.5;dy=(v-y+.5)%1-.5
  if irregular:
   angle=rng.uniform(0,math.tau);aspect=rng.uniform(.72,1.55);size=rng.uniform(.65,1.4)
   rx=(dx*math.cos(angle)+dy*math.sin(angle))/aspect;ry=(-dx*math.sin(angle)+dy*math.cos(angle))*aspect
   d=np.sqrt(rx*rx+ry*ry)/size
  else:d=np.sqrt(dx*dx+dy*dy)
  second=np.minimum(second,np.maximum(first,d));first=np.minimum(first,d)
 return first,second-first
specs=[('desiccated_clay','a98464',.95),('stony_loam','877762',.93),('talus_fragments','8d8880',.95),('alluvial_pebbles','9b9281',.83),('wind_scoured','b19875',.95),('ash_drift','79746f',.97),('humus_crumb','665340',.87),('pioneer_mat','61764a',.79)]
records=[]
bpy.ops.wm.read_factory_settings(use_empty=True)
for index,(id,tint,rough) in enumerate(specs):
 f=field(1361+index);fine=field(1491+index,5)
 dist,edge=cells(1407+index,38 if id in ('desiccated_clay','pioneer_mat') else 76,id in ('stony_loam','alluvial_pebbles','humus_crumb','talus_fragments'))
 cracks=1-smooth(.001,.007,edge)
 if id=='desiccated_clay':h=.36+smooth(.002,.025,edge)*.22+f*.12+fine*.03
 elif id=='stony_loam':
  pebble=np.clip(1-(dist/.028)**2,0,1)**.6
  h=.30+f*.20+fine*.075+pebble*.19
 elif id=='talus_fragments':h=.30+np.clip(1-dist/.058,0,1)*.34-cracks*.08+f*.10
 elif id=='alluvial_pebbles':h=.32+np.sqrt(np.clip(1-(dist/.043)**2,0,1))*.26+f*.10
 elif id=='wind_scoured':
  ripples=np.sin((u*5+v*13)*math.tau+np.sin((u-v)*math.tau)*1.8+f*4)
  h=.37+smooth(-.5,.9,ripples)*(.05+.10*smooth(.3,.65,f))+f*.14
 elif id=='ash_drift':
  bed=np.sin(v*math.tau*4+np.sin(u*math.tau)*1.5+f*2)*.5+.5
  h=.32+f*.23+bed*.09+fine*.06
 elif id=='humus_crumb':
  clod=np.clip(1-(dist/.055)**2,0,1)**.7
  h=.30+f*.20+clod*.12+fine*.09-cracks*.018
 elif id=='pioneer_mat':
  colonies=smooth(.50,.68,f+fine*.25)
  h=.34+f*.10+colonies*.15+fine*.075-cracks*.016
 amplitude={'desiccated_clay':.045,'stony_loam':.055,'talus_fragments':.09,'alluvial_pebbles':.065,'wind_scoured':.035,'ash_drift':.04,'humus_crumb':.045,'pioneer_mat':.035}[id]
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
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1400;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(PIC/'blender-soils.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'terraform-surfaces.blend'));bpy.ops.render.render(write_still=True)
(SRC/'terraform-surfaces.json').write_text(json.dumps({'version':1,'blender':bpy.app.version_string,'resolution':N,'channels':'linear normal XY / height / roughness','materials':records},ensure_ascii=False,indent=2)+'\n')
print('TERRAFORM_TEXTURES_COMPLETE',len(records),flush=True)
