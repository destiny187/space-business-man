"""Author geological scatter meshes in Blender, export and render."""
from pathlib import Path
import bpy, math, random, json, sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art/blender/surface-details'; OUT=ROOT/'우주-비즈니스/assets/models/surface-details'; PIC=ROOT/'docs/production/media/surface-details'
for d in (SRC,OUT,PIC): d.mkdir(parents=True,exist_ok=True)
rules=json.loads((ROOT/'우주-비즈니스/data/planet_diversity.json').read_text())
ids=[k for k,v in rules['archetypes'].items() if v['relief']>0]
all_ids=ids.copy()
selected=next((a.split('=',1)[1].split(',') for a in sys.argv if a.startswith('--families=')),[])
if selected:ids=[id for id in ids if id in selected]
previous=json.loads((SRC/'manifest.json').read_text()).get('assets',[]) if selected and (SRC/'manifest.json').exists() else []
records=[]
bpy.ops.wm.read_factory_settings(use_empty=True)
def linear(hexcode):
    return tuple(((int(hexcode[i:i+2],16)/255+.055)/1.055)**2.4 for i in (0,2,4))
def stone(name, rng, shape, center, size, colors):
    # Uneven rings give broad chipped faces, bevel lips and asymmetrical crowns.
    n=12 if shape=='round' else rng.choice([7,8,9])
    rings=[(0,.72),(.12,.96),(.42,1),(.8,.76),(1,.32)] if shape=='round' else [(0,.8),(.12,1),(.75,.88),(1,.58)]
    if name=='sedimentary':rings=[(0,.8),(.08,1),(.26,.95),(.30,.82),(.36,.95),(.60,.86),(.65,.73),(.72,.84),(1,.62)]
    if name=='crystalline':n=6;rings=[(0,.75),(.06,1),(.76,.95),(1,.05)]
    phases=[rng.uniform(.8,1.18) for _ in range(n)]; verts=[]; faces=[]
    drift=(rng.uniform(-.18,.18),rng.uniform(-.15,.15))
    for z,w in rings:
        for j in range(n):
            a=j*math.tau/n; r=phases[j]*w
            verts.append((center[0]+size[0]*(math.cos(a)*r+drift[0]*z),center[1]+size[1]*(math.sin(a)*r+drift[1]*z),center[2]+size[2]*z*(1+.12*math.sin(j*2.3))))
    faces.append(tuple(reversed(range(n))))
    for level in range(len(rings)-1):
        for j in range(n):faces.append((level*n+j,level*n+(j+1)%n,(level+1)*n+(j+1)%n,(level+1)*n+j))
    faces.append(tuple((len(rings)-1)*n+j for j in range(n)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    attr=mesh.color_attributes.new(name='Geology',type='FLOAT_COLOR',domain='CORNER')
    for poly in mesh.polygons:
        color=colors[0] if poly.normal.z<.25 else colors[1]
        f=rng.uniform(.9,1.08)
        for loop in poly.loop_indices:attr.data[loop].color=tuple(min(1,c*f) for c in color)+(1,)
        poly.use_smooth=shape=='round'
    return obj
for idx,key in enumerate(ids):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    t=rules['archetypes'][key];rng=random.Random(3701+{'sedimentary':0,'crystalline':1,'alkaline':2}.get(key,all_ids.index(key))*971)
    base=linear(t['rock']);top=tuple(a*.35+b*.65 for a,b in zip(base,linear(t['dust'])))
    if key=='volcanic':base=linear('302d35');top=linear('5b5150')
    material=bpy.data.materials.new(key+'_vertex_paint');material.use_nodes=True
    bs=material.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.93
    color=material.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='Geology';material.node_tree.links.new(color.outputs['Color'],bs.inputs['Base Color'])
    meshes=[]
    for variant in range(4):
        objects=[]
        count=[1,3,6,3][variant]
        for part in range(count):
            angle=part*2.4+rng.uniform(-.2,.2)
            center=(0,0,0) if count==1 else (math.cos(angle)*(.21 if variant==1 else .38),math.sin(angle)*.26,0)
            r=rng.uniform(.16,.28) if count>1 else .37
            shape='round' if key in ('continental','tundra') else 'chip'
            h=r*rng.uniform(.48,.8)
            if key in ('fractured','frozen','salt'):h*=.4 if variant!=3 else 1.2
            if variant==1:h*=.5
            if variant==3:r*=1.3;h*=1.45
            if key=='ochre':r*=1.15;h*=.7
            if key=='sedimentary':r*=1.5;h*=.65
            if key=='crystalline':r*=.7;h*=2.8
            if key=='alkaline':h*=1.15
            obj=stone(key,rng,shape,center,(r,r*rng.uniform(.55,1.0),h),(base,top));objects.append(obj)
            # Pale upper crust, snow caps, or porous cooled lava pits: actual geometry.
            if key in ('tundra','frozen') and part%2==0:
                objects.append(stone('frost_cap',rng,'round',(center[0]-.015,center[1],h*.65),(r*.82,r*.61,h*.32),(linear('b7c7d1'),linear('e1e8df'))))
            if key=='volcanic':
                for p in range(2):
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=r*.2,location=(center[0]+rng.uniform(-r*.4,r*.4),center[1]+rng.uniform(-r*.25,r*.25),h*.86))
                    cutter=bpy.context.object
                    backup=obj.data.copy()
                    mod=obj.modifiers.new('Weathered pore','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
                    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
                    if len(obj.data.polygons)==0:obj.data=backup
                    else:bpy.data.meshes.remove(backup)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=bpy.context.object;obj.name=key+'_'+str(variant)
        obj.data.materials.clear();obj.data.materials.append(material)
        for poly in obj.data.polygons:poly.material_index=0
        meshes.append(obj)
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(key+'.blend')))
    for variant,obj in enumerate(meshes):
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        asset=key+'_'+str(variant)
        bpy.ops.export_scene.gltf(filepath=str(OUT/(asset+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_cameras=False,export_lights=False,export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_attributes=True)
        obj.data.calc_loop_triangles()
        records.append({'id':'surface_'+asset,'name':t['name']+' · '+['독립석','판상 파편','잔해 군집','낮은 노두'][variant],'source':str((SRC/(key+'.blend')).relative_to(ROOT)),'model':'res://assets/models/surface-details/'+asset+'.glb','triangles':len(obj.data.loop_triangles),'archetype':key,'variant':variant,'geometry':'blender-authored','foliage':False,'group':'지표 자연물','title':t['name']})
    print('SURFACE_AUTHORED',key,flush=True)
(SRC/'manifest.json').write_text(json.dumps({'version':1,'blender':bpy.app.version_string,'assets':[r for r in previous if r['archetype'] not in selected]+records},ensure_ascii=False,indent=2)+'\n')
# Blender renderer shows every exported model in one contact sheet.
bpy.ops.wm.read_factory_settings(use_empty=True)
for i,row in enumerate(records):
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'우주-비즈니스'/row['model'].removeprefix('res://')))
    for obj in bpy.context.selected_objects:
        if obj.parent is None:obj.location+=Vector((i%4*1.8-2.7,(4-i//4)*1.6,0))
mat=bpy.data.materials.new('Studio floor');mat.diffuse_color=(.16,.19,.22,1)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));bpy.context.object.data.materials.append(mat)
bpy.ops.object.camera_add(location=(0,-12,23));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=17
scene=bpy.context.scene;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(1,-5,13));bpy.context.object.data.energy=2200;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=8
scene.world=bpy.data.worlds.new('Surface studio');scene.world.color=(.32,.32,.32);scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PIC/('blender-new-families.png' if selected else 'blender-catalog.png'))
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('new-families.blend' if selected else 'catalog.blend')));bpy.ops.render.render(write_still=True)
print('SURFACE_DETAILS_COMPLETE',len(records),flush=True)
