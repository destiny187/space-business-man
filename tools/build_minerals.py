"""Blender-only mineral outcrops: no host rock, terrain, plinth or soil meshes.
Run Blender --background --python tools/build_minerals.py.
The resource catalog is seed-ready metadata; it does not alter legacy recipes.
"""
from pathlib import Path
import bpy, math, random, json, sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art/blender/minerals'; OUT=ROOT/'우주-비즈니스/assets/models'; PRE=ROOT/'docs/production/media/minerals/blender'
for p in (SRC,OUT,PRE):p.mkdir(parents=True,exist_ok=True)
# id, Korean name, material colour, silhouette, geology tags, depth tags
ROWS=[
 ('iron','철','7798ae','block',['metallic','volcanic'],['surface','shallow','middle']),
 ('copper','구리','d77d47','branch',['hydrothermal','metallic'],['surface','shallow','middle']),
 ('aluminum','알루미늄','bbc8d2','plate',['weathered','rocky'],['surface','shallow']),
 ('silicon','규소','667f98','blade',['silicate','rocky'],['surface','shallow','middle']),
 ('titanium','티타늄','8b91b2','plate',['volcanic','metallic'],['middle','deep']),
 ('nickel','니켈','94aa85','nodule',['metallic','ultramafic'],['shallow','middle']),
 ('lithium','리튬','e5b4ce','prism',['pegmatite','arid'],['shallow','middle']),
 ('sulfur','황','efcd32','bipyramid',['volcanic','hydrothermal'],['surface','shallow']),
 ('phosphate','인산염','9cceab','barrel',['sedimentary','hydrothermal'],['surface','shallow','middle']),
 ('rare_earth','희토류','b88b6a','wedge',['alkaline','pegmatite'],['middle','deep']),
 ('stellarite_ore','성핵광','ffc779','radial',['stellar_anomaly'],['deep','cavity']),
 ('darkstone_ore','암흑광','494361','dark_layers',['dark_anomaly'],['deep','cavity']),
 ('ruby','루비','d83262','barrel',['metamorphic','hot'],['shallow','middle','deep']),
 ('sapphire','사파이어','3b79dc','barrel',['metamorphic','high_pressure'],['middle','deep']),
 ('emerald','에메랄드','36b987','prism',['hydrothermal','groundwater'],['middle','deep']),
 ('diamond','다이아몬드','c9e9f0','octahedron',['deep_mantle'],['deep','cavity']),
 ('stone','암석','a99ba9','rock',['rocky'],['surface','shallow','middle']),
 ('ice','얼음','87dbec','blade',['icy','cold'],['surface','shallow']),
 ('crystal','희귀 결정','a777db','prism',['legacy_crystal'],['surface','middle'])]
def linear(h):
 a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in a)
def mat(name,col,mul=1,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 c=tuple(min(1,v*mul) for v in linear(col))+(1,)
 m.diffuse_color=c;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=c
 p.inputs['Roughness'].default_value=.48;p.inputs['Metallic'].default_value=.25
 if emission:p.inputs['Emission Color'].default_value=c;p.inputs['Emission Strength'].default_value=emission
 return m

def piece(name,loc,r,h,sides,style,mats,rotation=(0,0,0)):
 # Wound outward. Crystals have actual terminations and cleavage planes.
 if style=='octahedron':rings=[(-.12,.02),(h*.48,r),(h,.02)];sides=4
 elif style in ('bipyramid','wedge'):rings=[(-.12,.13*r),(h*.4,r),(h*.63,.82*r),(h,.08*r)]
 elif style=='barrel':rings=[(-.12,.6*r),(h*.15,r),(h*.75,r*.9),(h,.55*r)]
 elif style in ('prism','blade','radial'):rings=[(-.12,.8*r),(h*.72,r),(h*.9,.7*r),(h,.04*r)]
 else:rings=[(-.12,.8*r),(h*.2,r),(h*.83,r*.93),(h,r*.65)]
 verts=[]
 for z,rr in rings:
  for i in range(sides):
   a=math.tau*i/sides;verts.append((math.cos(a)*rr,math.sin(a)*rr,z))
 faces=[tuple(reversed(range(sides)))]
 for k in range(len(rings)-1):
  for i in range(sides):j=(i+1)%sides;faces.append((k*sides+i,k*sides+j,(k+1)*sides+j,(k+1)*sides+i))
 faces.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=rotation
 for m in mats:mesh.materials.append(m)
 for f in mesh.polygons:f.material_index=(f.index//sides)%len(mats) if style=='dark_layers' else (1 if f.index%7==0 else 0)
 bevel=ob.modifiers.new('Fine mineral edge','BEVEL');bevel.width=.018;bevel.segments=2
 bevel.affect='EDGES';ob.modifiers.new('Weighted facet normals','WEIGHTED_NORMAL')
 return ob

def build(row,index,variant="a"):
 key,name,col,style,geology,depth=row;random.seed(8100+index+(1709 if variant=="b" else 0))
 asset_key=key+("_b" if variant=="b" else "")
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 materials=[mat(key+'_body',col),mat(key+'_cleavage',col,1.35,.12 if key=='stellarite_ore' else 0)]
 if key=='darkstone_ore':materials.append(mat(key+'_inner_lamina','9c78b6',1,.08))
 count=9 if style in ('radial','branch','dark_layers') else 7
 if variant=='b':count=5 if style not in ('branch','radial') else 6
 for i in range(count):
  a=i*2.39996;rr=0 if i==0 else (.46 if i<4 else .78)
  x,y=math.cos(a)*rr,math.sin(a)*rr
  h=(1.9 if i==0 else random.uniform(.65,1.45));r=random.uniform(.23,.4)
  rot=(math.sin(a)*.16,math.cos(a)*.19,a)
  if style=='radial':rot=(-math.sin(a)*.6,math.cos(a)*.6,a);h*=1.05;r*=.73
  if style in ('plate','dark_layers'):r*=1.35;h*=.75
  if key=='iron':h*=.62;r*=1.45
  if key=='ruby':h*=.58;r*=1.3
  if key=='sapphire':h*=.8;r*=1.15
  if key=='diamond':r*=1.4;h=r*2.1
  if key=='aluminum':h*=.65;r*=1.18
  if key=='titanium':rot=(-math.sin(a)*.4,math.cos(a)*.4,a)
  if variant=='b':
   # A low asymmetric seam: a dominant off-centre fragment and a tapering trail.
   x=-.7+i*.31;y=math.sin(i*2.2)*.28
   h*=.62 if i!=1 else .92;r*=1.08 if i<3 else .82
   rot=(rot[0]*.6,rot[1]*.6,a+.35)
  ob=piece(key+'_%02d'%i,(x,y,0),r,h,6 if style not in ('block','plate','dark_layers','blade') else 4,style,materials,rot)
  if style in ('plate','dark_layers'):ob.scale.y=.35
  if style=='blade':ob.scale.y=.45
  if style in ('nodule','rock'):
   bpy.data.objects.remove(ob,do_unlink=True)
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if style=='nodule' else 1,radius=1,location=(x,y,h*.27))
   ob=bpy.context.object;ob.name=key+'_pure_chunk_%02d'%i;ob.scale=(r*1.6,r*1.4,h*.4);ob.data.materials.append(materials[0])
   bevel=ob.modifiers.new('Worn mineral corners','BEVEL');bevel.width=.045;bevel.segments=3;ob.modifiers.new('Facet normals','WEIGHTED_NORMAL')
  if style=='branch':
   ob.scale=(.55,.65,.8)
   for j in range(2):
    branch=piece(key+'_native_branch',(x,y,h*(.35+j*.2)),.11,h*.4,5,'block',materials,(.5*math.sin(a+j),.65*math.cos(a+j),a))
 mineral_objects=list(bpy.context.scene.objects)
 # Save only editable mineral objects. Studio floor/light/camera never enter exports.
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(asset_key+'.blend')))
 bpy.ops.object.select_all(action='DESELECT')
 for ob in mineral_objects:ob.select_set(True)
 model=OUT/('ore_'+asset_key+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
 tris=0
 deps=bpy.context.evaluated_depsgraph_get()
 for ob in mineral_objects:
  me=ob.evaluated_get(deps).to_mesh();me.calc_loop_triangles();tris+=len(me.loop_triangles);ob.evaluated_get(deps).to_mesh_clear()
 # Contact sheet uses true Cycles renders. A temporary neutral studio ground is excluded from source and GLB.
 bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.name='STUDIO_ONLY';floor.location.z=-.19;floor.data.materials.append(mat('studio','253647'))
 bpy.ops.object.camera_add(location=(4,-6,3.2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.8;bpy.context.scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(1,-4,7));bpy.context.object.data.energy=900;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=4
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.22,.22,.22);scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.render.filepath=str(PRE/(asset_key+'.png'));bpy.ops.render.render(write_still=True)
 return dict(id=asset_key,name=name,category='gem' if 12<=index<=15 else ('industrial' if index<12 else 'legacy_basic'),color=col,model='res://assets/models/ore_'+asset_key+'.glb',source='art/blender/minerals/'+asset_key+'.blend',geometry='mineral-only',triangles=tris,geology_tags=geology,depth_tags=depth,placement=dict(pivot='surface',embed_m=.12,terrain_included=False),distribution_status='candidate_tags_only',fictional=key in ('stellarite_ore','darkstone_ore'))
rows=json.loads((SRC/'manifest.json').read_text()) if '--variant-b' in sys.argv else [build(row,i) for i,row in enumerate(ROWS)]
for i,row in enumerate(rows):
 b=build(ROWS[i],i,'b')
 row['variants']=[dict(id='a',model=row['model'],source=row['source'],triangles=row['triangles']),dict(id='b',model=b['model'],source=b['source'],triangles=b['triangles'])]
 row['placement'].update(visual_version=1,yaw_degrees=[0,360],uniform_scale=[.85,1.15],tilt_degrees=0)

data=dict(schema_version=1,content_version='minerals-v2',status='assets_ready_distribution_pending',resources={r['id']:r for r in rows})
(ROOT/'우주-비즈니스/data/minerals.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(SRC/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
render_path=ROOT/'우주-비즈니스/data/render_assets.json'
render_rows=json.loads(render_path.read_text())
for row in [dict(r,id=r['id']+('_b' if v['id']=='b' else ''),name=r['name']+' '+v['id'].upper(),model=v['model'],source=v['source']) for r in rows for v in r['variants']]:
 item=next((r for r in render_rows if r['id']=='ore_'+row['id']),None)
 fields=dict(id='ore_'+row['id'],title='광물 · 보석',name=row['name'],group='자원',model=row['model'],source=row['source'],geometry='mineral-only-remodeled',foliage=False)
 if item is None:render_rows.append(fields)
 else:item.update(fields)
render_path.write_text(json.dumps(render_rows,ensure_ascii=False,indent=2)+'\n')
legacy_path=ROOT/'art/blender/manifest.json'
legacy_rows=json.loads(legacy_path.read_text())
for row in legacy_rows:
 if row['id'].startswith('ore_'):
  new=next((r for r in rows if 'ore_'+r['id']==row['id']),None)
  if new:
   row.update(source=new['source'],generator='tools/build_minerals.py',triangles=new['triangles'])
   row.pop('editable_objects',None);row.pop('export_objects',None)
legacy_path.write_text(json.dumps(legacy_rows,ensure_ascii=False,indent=2)+'\n')
print('MINERALS COMPLETE',sum(len(r['variants']) for r in rows),'models',sum(v['triangles'] for r in rows for v in r['variants']),'triangles')
