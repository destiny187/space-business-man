"""Author refined orbital relief and cloud volumes, keeping planet IDs and seeds."""
from pathlib import Path
import bpy,sys,json,math,hashlib
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_solar_system as S
DEST=ROOT/('docs/production/media/planet-surfaces-v2/blender-planets' if any(a.startswith('--families=') for a in sys.argv) else 'docs/production/media/ink-life/planets');DEST.mkdir(parents=True,exist_ok=True)
RULES=json.loads((ROOT/'우주-비즈니스/data/planet_diversity.json').read_text())
original_surface=S.surface

def solar_surface(kind,v):
    radius,color,cloud=original_surface(kind,v);x,y,z=v.T;lon=np.arctan2(y,x);lat=np.arcsin(np.clip(z,-1,1));detail=S.noise(v,3.3);broad=S.noise(v,1.4)
    if kind=='earth':
        land=S.land_mask(lon,lat);near=land.astype(float)
        for dx,dy in [(.009,0),(-.009,0),(0,.009),(0,-.009)]:near+=S.land_mask(lon+dx,lat+dy)
        coast=(near>0)&(near<5);shelf=coast&~land
        color[shelf]=S.mix(color[shelf],S.rgb('398eaa'),.45)
        color[coast&land]=S.mix(color[coast&land],S.rgb('a5aa72'),.24)
        ridge=np.maximum(0,.48-np.abs(S.noise(v,3.8)))*np.maximum(0,broad+.1)*land
        radius+=ridge*.022
        color=S.mix(color,S.rgb('8b8965'),np.clip(ridge*1.7,0,.28))
        polar=np.clip((np.abs(lat)-1.2)*4,0,.6)*land;color=S.mix(color,S.rgb('e9efe3'),polar)
        wind=v.copy();wind[:,0]+=.12*np.sin(lat*9);wind[:,1]+=.07*np.cos(lon*4)
        cloud=S.noise(wind,2.5)+.20*np.sin(lon*5+lat*11)-.48;cloud[np.abs(lat)>1.35]=-1
    elif kind=='mercury':
        basins=np.clip((-broad-.22)*2,0,.6);color=S.mix(color,S.rgb('635e60'),basins)
        rng=np.random.default_rng(8193)
        for k in range(15):
            axis=rng.normal(size=3);axis/=np.linalg.norm(axis);d=np.arccos(np.clip(v@axis,-1,1))/rng.uniform(.018,.035)
            rim=np.exp(-((d-1)/.24)**2);radius+=rim*.0025;color=S.mix(color,S.rgb('c1b7a7'),rim*.25)
    elif kind=='mars':
        for offset in [-.075,.08]:
            branch=np.exp(-((lat+.12+offset+.06*np.sin(lon*6))/.018)**2)*np.exp(-((lon+1.55)/.45)**6)
            radius-=branch*.005;color=S.mix(color,S.rgb('683c30'),branch*.44)
        volcano=np.exp(-(((lon+2.2)/.19)**2+((lat-.32)/.14)**2));radius+=volcano*.012;color=S.mix(color,S.rgb('ad6847'),volcano*.35)
    elif kind=='venus':
        swirl=np.sin(lat*12+np.sin(lon*3+detail)*1.7);color=S.mix(color,S.rgb('fae8bb'),np.clip(swirl*.24,0,.24))
    elif kind in ['jupiter','saturn','uranus','neptune']:
        warp=lat+.035*np.sin(lon*4+lat*9)+.012*detail
        wisps=np.sin(warp*54+np.sin(lon*10)*.25)
        color=S.mix(color,S.rgb('ebdec5') if kind in ['jupiter','saturn'] else S.rgb('a6d5da'),np.clip((wisps-.35)*.14,0,.09))
        if kind=='neptune':
            d=((lon+1.4)/.22)**2+((lat+.26)/.09)**2;color=S.mix(color,S.rgb('c2e2de'),np.exp(-((np.sqrt(d)-1.3)/.21)**2)*.35)
    return radius,np.clip(color,0,1),cloud
S.surface=solar_surface;S.RENDER=DEST


def render_variant(name,obj,traits):
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Planet review');scene.world.color=(.025,.035,.05)
    scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    bpy.ops.object.camera_add(location=(2,-4,1.6));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.65;scene.camera=cam
    for loc,power,size in [((-3,-4,5),600,3),((4,-1,2),140,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(DEST/(name+'.png'));bpy.ops.render.render(write_still=True)


def variant_fields(v,idx,name,t):
    """Continuous source fields shared by Blender meshes and orbital map baking."""
    v=v.copy();x,y,z=v.T;phase=idx*1.783
    broad=S.noise(v+phase,1.0);fine=S.noise(v+phase*.31,3.6);ridges=1-np.abs(S.noise(v+phase*.2,2.8))
    h=np.clip(.48+broad*.36+fine*.10,0,1);crater=np.zeros(len(v));feature=np.clip(ridges*.5+fine*.1,0,1);gas=t['kind'] in ['gas_giant','ice_giant']
    radius=np.ones(len(v));rng=np.random.default_rng(710+idx)
    if not gas:
        for k in range(55 if name=='cratered' else 12):
            axis=rng.normal(size=3);axis/=np.linalg.norm(axis);d=np.arccos(np.clip(v@axis,-1,1))/rng.uniform(.025,.17)
            crater+=np.exp(-((d-1)/.22)**2)*.8-np.exp(-((d/.72)**4))*.55
        radius+=(h-.5)*.007+crater*.0038
        if name in ['fractured','volcanic']:
            seams=np.exp(-(np.sin(x*8+y*3+phase+np.sin(z*4))/.12)**2);radius-=seams*.004;feature=1-seams
        elif name in ['oxidized','ochre']:
            mesa=np.floor(h*7)/7;radius+=mesa*.005;feature=np.clip(.5+np.sin(h*41)*.3,0,1)
        elif name in ['continental','tundra']:
            ranges=np.maximum(0,ridges-.65)*np.maximum(0,h-.40);radius+=ranges*.027;feature=np.clip(ranges*9,0,1)
        elif name=='sedimentary':
            strata=np.sin(h*54+fine*.8);radius+=np.floor(h*9)/9*.010;feature=np.clip(.5+strata*.45,0,1)
        elif name=='crystalline':
            peaks=np.maximum(0,ridges-.65);radius+=peaks*.035;feature=np.clip(peaks*4+fine*.2,0,1)
        elif name=='alkaline':
            veins=np.exp(-(np.sin(x*7+y*5+z*3+fine)/.16)**2);radius+=veins*.004;feature=veins
        elif name=='salt':
            basin=np.exp(-((h-.40)/.055)**2);radius-=basin*.003;feature=basin
    else:
        oblateness=.035 if t['kind']=='gas_giant' else .02;v[:,2]*=1-oblateness;feature=.5+.35*np.sin(z*17+fine)
    return v*radius[:,None],np.column_stack([h,np.clip(.5+crater*.5,0,1),feature])


def variants():
    src=ROOT/'art/blender/planet-variants';out=ROOT/'우주-비즈니스/assets/models/planet-variants';records=[]
    selected=next((a.split('=',1)[1].split(',') for a in sys.argv if a.startswith('--families=')),[])
    if selected and (src/'manifest.json').exists():records=[r for r in json.loads((src/'manifest.json').read_text()) if r['id'] not in selected]
    for idx,(name,t) in enumerate(RULES['archetypes'].items()):
        if selected and name not in selected:continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=256,ring_count=128,radius=1);obj=bpy.context.object;obj.name='Surface';mesh=obj.data
        v=np.array([tuple(p.co) for p in mesh.vertices]);v/=np.linalg.norm(v,axis=1)[:,None];x,y,z=v.T;phase=idx*1.783
        coords,masks=variant_fields(v,idx,name,t)
        h,impact,feature=masks.T
        for vert,co in zip(mesh.vertices,coords):vert.co=co
        for f in mesh.polygons:f.use_smooth=True
        attr=mesh.color_attributes.new(name='Relief',type='FLOAT_COLOR',domain='POINT')
        attr.data.foreach_set('color',np.column_stack([h,impact,feature,np.ones(len(v))]).astype(np.float32).ravel())
        mat=bpy.data.materials.new(name+'_relief');mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
        vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Relief';ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*S.rgb(t['rock']),1);ramp.color_ramp.elements[1].color=(*S.rgb(t['dust']),1)
        links.new(vc.outputs['Color'],ramp.inputs[0]);links.new(ramp.outputs[0],bs.inputs['Base Color']);obj.data.materials.append(mat)
        bpy.context.scene.unit_settings.system='METRIC';bpy.ops.wm.save_as_mainfile(filepath=str(src/(name+'.blend')))
        links.new(vc.outputs['Color'],bs.inputs['Base Color']);lods={}
        for lod in ['near','far']:
            if lod=='far':
                bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Far orbital silhouette','DECIMATE');mod.ratio=.18;bpy.ops.object.modifier_apply(modifier=mod.name)
            output=out/(name+('_lod1' if lod=='far' else '')+'.glb');bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
            obj.data.calc_loop_triangles();lods[lod]={'model':'res://assets/models/planet-variants/'+output.name,'triangles':len(obj.data.loop_triangles),'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
        bpy.ops.wm.open_mainfile(filepath=str(src/(name+'.blend')));obj=bpy.data.objects['Surface'];render_variant(name,obj,t)
        records.append({'id':name,'kind':t['kind'],'source':str((src/(name+'.blend')).relative_to(ROOT)),'model':lods['near']['model'],'lod_model':lods['far']['model'],'triangles':lods['near']['triangles'],'lod_triangles':lods['far']['triangles'],'mask':'R elevation / G impact rim / B geologic structure','version':2,'art_revision':'surface-v2' if name in ['sedimentary','crystalline','alkaline'] else 'ink-life-1','lods':lods})
        (src/'manifest.json').write_text(json.dumps(records,indent=2)+'\n');(out/'manifest.json').write_text(json.dumps(records,indent=2)+'\n');print('INK_PLANET_EXPORTED',name,flush=True)

def solar():
    S.main()
    for manifest in [S.SOURCE/'manifest.json',S.OUTPUT/'manifest.json']:
        rows=json.loads(manifest.read_text())
        for row in rows:row.update(art_revision='ink-life-1',generator='tools/build_ink_planets.py')
        manifest.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    if '--variants-only' not in sys.argv:solar()
    if not any(a.startswith('--planet=') for a in sys.argv) and '--solar-only' not in sys.argv:variants()
