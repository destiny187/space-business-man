"""Blender-authored planet relief masks and oblate gas envelopes; deterministic v1."""
import bpy, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
# Keep this historical entry point from overwriting the approved revised assets.
manifest=ROOT/'art/blender/planet-variants/manifest.json'
if manifest.exists() and any(r.get('art_revision')=='ink-life-1' for r in json.loads(manifest.read_text())):
 import sys
 sys.path.insert(0,str(ROOT/'tools'))
 import build_ink_planets
 build_ink_planets.variants()
 raise SystemExit()
SRC=ROOT/'art/blender/planet-variants'; OUT=ROOT/'우주-비즈니스/assets/models/planet-variants'; RENDER=ROOT/'docs/production/media/planet-diversity/blender'
for d in (SRC,OUT,RENDER):d.mkdir(parents=True,exist_ok=True)
rules=json.loads((ROOT/'우주-비즈니스/data/planet_diversity.json').read_text()); records=[]
for idx,(name,t) in enumerate(rules['archetypes'].items()):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=192,ring_count=96,radius=1)
 obj=bpy.context.object;obj.name='Surface';mesh=obj.data
 v=np.array([tuple(x.co) for x in mesh.vertices]);x,y,z=v.T
 phase=idx*1.783
 h=(np.sin(x*4+y*2+phase+np.sin(z*5))+.5*np.sin(y*11-z*7+phase)+.2*np.cos(z*23+x*17))/1.7
 h=np.clip(.5+h*.35,0,1);mark=np.zeros(len(v)); gas=t['kind'] in ('gas_giant','ice_giant')
 if not gas:
  rng=np.random.default_rng(710+idx)
  for k in range(32 if name=='cratered' else 9):
   axis=rng.normal(size=3);axis/=np.linalg.norm(axis);d=np.arccos(np.clip(v@axis,-1,1))/rng.uniform(.025,.14)
   mark+=np.exp(-((d-1)/.19)**2)*.8-np.exp(-((d/.75)**4))*.5
  radius=1+(h-.5)*.009+mark*.004
  if name in ('fractured','volcanic'):radius-=np.exp(-(np.sin(x*9+y*3+phase)/.12)**2)*.003
  v*=radius[:,None]
 else:v[:,2]*=1-[.035,.065,.02][idx%3]
 for vertex,co in zip(mesh.vertices,v):vertex.co=co
 for face in mesh.polygons:face.use_smooth=True
 attr=mesh.color_attributes.new(name='Relief',type='FLOAT_COLOR',domain='POINT')
 for i,c in enumerate(attr.data):c.color=(float(h[i]),float(np.clip(.5+mark[i]*.5,0,1)),.5,1)
 m=bpy.data.materials.new(name+'_relief');m.use_nodes=True
 nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.92
 vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Relief';ramp=nodes.new('ShaderNodeValToRGB')
 def col(s):return tuple((int(s[j:j+2],16)/255)**2.2 for j in (0,2,4))+(1,)
 ramp.color_ramp.elements[0].color=col(t['rock']);ramp.color_ramp.elements[1].color=col(t['dust'])
 links.new(vc.outputs['Color'],ramp.inputs[0]);links.new(ramp.outputs[0],bs.inputs['Base Color']);obj.data.materials.append(m)
 # Save editable authored geometry before export. Game adds seeded palettes, oceans and animated gas.
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 links.new(vc.outputs['Color'],bs.inputs['Base Color'])
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
 links.new(ramp.outputs[0],bs.inputs['Base Color'])
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
 scene.render.resolution_x=320;scene.render.resolution_y=320;scene.render.resolution_percentage=100;scene.world.color=(.04,.04,.04)
 bpy.ops.object.camera_add(location=(2,-4,1.6));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.7;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(-3,-4,5));bpy.context.object.data.energy=650;bpy.context.object.data.size=4
 bpy.context.object.rotation_euler=(-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(RENDER/(name+'.png'));bpy.ops.render.render(write_still=True)
 records.append(dict(id=name,kind=t['kind'],source=str((SRC/(name+'.blend')).relative_to(ROOT)),model='res://assets/models/planet-variants/'+name+'.glb',triangles=sum(len(f.vertices)-2 for f in mesh.polygons),mask='COLOR.r authored relief / COLOR.g crater rims',version=1,validation='Blender rendered; rerun Godot test_planet_diversity.gd after regeneration'))
 print('VARIANT DONE',name,flush=True)
(SRC/'manifest.json').write_text(json.dumps(records,indent=2)+'\n');(OUT/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
