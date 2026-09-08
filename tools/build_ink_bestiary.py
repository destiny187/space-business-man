"""INK natural anatomy revision: selected anatomy corrections, preserving reviewed originals.
Blender --background --python tools/build_ink_bestiary.py -- [IDs/families]
"""
from pathlib import Path
import bpy,sys,json,math,hashlib,random
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_bestiary as B
import build_aberrant_bestiary as A
import ink_blender as ink
REV='ink-life-1'
DEST=ROOT/'docs/production/media/ink-life';FORMS=B.DATA/'forms.json'
BASE=json.loads((DEST/'baseline.json').read_text());SELECT=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if not SELECT:SELECT=json.loads((DEST/'selection.json').read_text())['rebuild']
ORIGINAL_OVAL=B.oval

def oval(name,p,s,slot='main',parent=None,seg=24):
    # Broader load-bearing bodies with a tapered rear and a quiet ventral plane.
    o=ORIGINAL_OVAL(name,p,s,slot,parent,max(seg,32))
    body=any(t in name.lower() for t in ['torso','thorax','mantle','abdomen','cranium','muzzle','body','foot','knot','sac'])
    if body and min(s)>.07:
        for v in o.data.vertices:
            y=v.co.y/max(s[1],.001);z=v.co.z/max(s[2],.001)
            v.co.x*=1.02-.12*y+.035*math.cos(y*math.pi)
            if z<-.32:v.co.z=(-.32+(z+.32)*.78)*s[2]
    return o

def horn(name,a,b,r,slot='bone',parent=None):
    a,b=Vector(a),Vector(b);d=b-a;axis=d.normalized();side=axis.cross(Vector((0,1,0)))
    if side.length<.01:side=Vector((1,0,0))
    side.normalize();up=axis.cross(side).normalized();verts=[];faces=[];n=20;steps=8
    for j in range(steps):
        t=j/(steps-1);center=a+d*t+Vector((0,d.length*.12,0))*math.sin(t*math.pi)
        rad=r*(1-t)**.78+.006
        for k in range(n):
            angle=k*math.tau/n;verts.append(tuple(center+(side*math.cos(angle)+up*math.sin(angle))*rad))
    faces.append(tuple(reversed(range(n))))
    for j in range(steps-1):
        for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    faces.append(tuple((steps-1)*n+k for k in range(n)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    return B.finish(o,name,slot,parent or B.BODY,0,True)

def blade(name,pts,width,slot='secondary',parent=None):
    # Sample the authored centreline; perpendicular blade width replaces global-X strips.
    points=[Vector(p) for p in pts];lengths=[0.0]
    for a,b in zip(points,points[1:]):lengths.append(lengths[-1]+(b-a).length)
    total=max(.001,lengths[-1]);verts=[];faces=[];count=max(10,len(points)*2)
    for j in range(count):
        t=j/(count-1);dist=t*total;idx=min(len(points)-2,next((i for i in range(len(points)-1) if lengths[i+1]>=dist),len(points)-2))
        w=(dist-lengths[idx])/max(.001,lengths[idx+1]-lengths[idx]);center=points[idx].lerp(points[idx+1],w);d=(points[idx+1]-points[idx]).normalized()
        side=d.cross(Vector((0,0,1)))
        if side.length<.1:side=Vector((1,0,0))
        side.normalize();normal=side.cross(d).normalized();span=math.sin(math.pi*t)**.75*width
        for u in [-1,-.5,0,.5,1]:
            lift=(1-u*u)*span*.21+math.sin(t*math.pi*2)*span*.08
            verts.append(tuple(center+side*span*u+normal*lift))
    for j in range(count-1):
        for k in range(4):n=j*5+k;faces.append((n,n+1,n+6,n+5))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    B.finish(o,name,slot,parent or B.BODY,0,True)
    mod=o.modifiers.new('INK solid organic blade','SOLIDIFY');mod.thickness=.028
    mod=o.modifiers.new('INK rounded blade edge','BEVEL');mod.width=.009;mod.segments=2
    return o

# Both constructors use the same improved authoring primitives.
B.oval=oval;B.horn=horn;B.blade=blade;A.oval=oval;A.horn=horn;A.blade=blade

def joint_shape(row):
    family=row['family'];head=bpy.data.objects.get('Anim_Head');v=int(row['anatomy']);category=row['category']
    # Joint cushions close the old capsule seams without crossing animation parents.
    for leg in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Leg')]:
        upper=next((o for o in leg.children if o.name.startswith('Upper leg')),None)
        if upper:
            radius=max(abs(v.co.x) for v in upper.data.vertices)
            extent=max(v.co.z for v in upper.data.vertices)-radius*.5
            knee=upper.location+upper.rotation_euler.to_matrix()@Vector((0,0,extent))
            oval('Knee articulation cushion',knee,(radius*1.05,)*3,'secondary',leg)
            oval('Proximal limb shoulder',(0,0,0),(radius*1.12,radius*1.28,radius*1.12),'main',leg)
    # Defined anatomical additions, parented to the existing motion joints.
    if head and family in ['grazer','stalker','burrower','lithic','runner']:
        cranium=next((o for o in head.children if o.name.startswith('Cranium')),None)
        sx,sy,sz=tuple(cranium.dimensions[i]/2 for i in range(3)) if cranium else (.4,.5,.3)
        if family!='runner':
            for side in [-1,1]:
                oval('Inset nasal pit',(side*sx*.28,-sy*.98,-sz*.05),(.049,.030,.028),'dark',head)
                B.tube('Muzzle fold',[(side*.03,-sy*1.04,-sz*.22),(side*sx*.38,-sy*1.01,-sz*.27),(side*sx*.64,-sy*.81,-sz*.22)],.016,'secondary',head)
        if row.get('eye_count',2)>0:
            for side in [-1,1]:
                B.tube('Orbital ridge',[(side*sx*.38,-sy*.77,sz*.45),(side*sx*.72,-sy*.84,sz*.54),(side*sx*.96,-sy*.62,sz*.42)],.032,'main',head)
        if family in ['grazer','stalker']:
            for side in [-1,1]:blade('Concave sensory pinna',[(side*sx*.7,.05,sz*.75),(side*(sx+.14),.06,sz+.22),(side*(sx+.21),.10,sz+.4)],.105,'secondary',head)
    if family in ['carapace','mantid']:
        for limb in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith(('Anim_Leg','Anim_Arm'))]:
            oval('Protective joint condyle',(0,0,0),(.17,.19,.16),'secondary',limb)
        for j in range(4):
            z=1.32 if family=='mantid' else .87
            B.tube('Abdominal vent seam',[(-.28,.18+j*.19,z),(-.31,.19+j*.19,z+.055),(-.20,.20+j*.19,z+.09)],.023,'accent')
    if family in ['winged','runner','swimmer','ray']:
        for limb in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Wing')]:
            sign=-1 if limb.name.endswith('L') else 1
            oval('Wing root tendon',(sign*.1,.02,0),(.18,.31,.16),'main',limb)
        if family in ['swimmer','ray'] and head:
            for side in [-1,1]:
                for j in range(3):B.tube('Recessed branchial fold',[(side*.32,.04+j*.09,.10),(side*.37,.04+j*.09,0),(side*.31,.04+j*.09,-.10)],.019,'secondary',head)
    if family in ['lithic','burrower','coil']:
        # Large soft-edged scutes with visible inset centres rather than fine scratches.
        for plate in [o for o in bpy.context.scene.objects if o.type=='MESH' and ('shield' in o.name.lower() or 'scale' in o.name.lower())]:
            for mod in plate.modifiers:
                if mod.type=='BEVEL':mod.segments=4;mod.width*=1.2
    if family=='slug':
        for side in [-1,1]:
            B.tube('Mantle skirt fold',[(side*.42,-.74,.36),(side*.60,-.25,.32),(side*.59,.42,.32),(side*.34,.86,.38)],.048,'secondary')
    if family in ['mist_leaf','canopy_tree','aquatic_frond']:
        # Existing fronds now have curved broad blades; add a real growth bud at each junction.
        for fr in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Frond')]:
            oval('Growth node',(0,0,.065),(.09,.085,.12),'main',fr)
    if family=='spore_fungus':
        for fr in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Frond')]:
            cap=next((o for o in fr.children if o.name.startswith('Thick umbrella')),None)
            if cap:
                z=cap.location.z-.10
                for k in range(8):
                    a=k*math.tau/8;B.tube('Radial underside gill',[(.12+math.cos(a)*.07,math.sin(a)*.07,z-.025),(.12+math.cos(a)*.30,math.sin(a)*.30,z)],.018,'secondary',fr)
    if family=='crystal_fan':
        for fr in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Frond')]:
            for side in [-1,1]:horn('Mineral basal offset',(side*.07,0,.04),(side*.21,.04,.31+.035*v),.08,'accent',fr)
    if category=='microbe':
        for fr in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('Anim_Frond')]:
            for sac in [o for o in list(fr.children) if o.type=='MESH' and ('vesicle' in o.name.lower() or 'gas sac' in o.name.lower())]:
                pos=sac.location.copy();pos.z+=sac.dimensions.z*.46
                oval('Exposed reaction nucleus',pos,(.044,.048,.04),'accent',fr)
            if family=='thermal_colony':
                for k in range(3):blade('Mineral vent flange',[(0,0,.05),(.16,0,.12+k*.07),(.21,0,.2+k*.07)],.095,'secondary',fr)
    if family in ['blind_harp','spiral_maw','tripod_bell','lantern_sail','eye_orchard','asym_pincer','ribbon_colony','window_sac','crown_stalker','manymouth']:
        for limb in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith(('Anim_Leg','Anim_Arm'))]:
            oval('Organic joint collar',(0,0,0),(.125,.14,.13),'main',limb)
        for jaw in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith(('Anim_Jaw','Anim_Petal'))]:
            if family in ['spiral_maw','manymouth','window_sac']:
                # Preserve the existing dark cavity, teeth and sensory topology.
                oval('Palatal muscle',(0,.04,-.1),(.13,.075,.09),'secondary',jaw)
        if family in ['blind_harp','lantern_sail','ribbon_colony']:
            for ap in [o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith(('Anim_Appendage','Anim_Frond','Anim_Segment'))]:
                oval('Elastic membrane anchorage',(0,0,.02),(.10,.095,.085),'secondary',ap)
        if family in ['eye_orchard','crown_stalker','asym_pincer','window_sac']:
            for side in [-1,1]:B.tube('Ventral respiratory crease',[(side*.12,-.32,.44),(side*.25,-.34,.5),(side*.32,-.27,.58)],.025,'secondary')

def render_source(row):
    bpy.context.view_layer.update();scene=bpy.context.scene
    pts=[o.matrix_world@Vector(v) for o in scene.objects if o.type=='MESH' for v in o.bound_box]
    lo=Vector(tuple(min(v[i] for v in pts) for i in range(3)));hi=Vector(tuple(max(v[i] for v in pts) for i in range(3)));center=(lo+hi)/2;size=(hi-lo).length
    scene.world=bpy.data.worlds.new('INK life review');scene.world.color=(.14,.14,.14)
    bpy.ops.object.camera_add(location=center+Vector((1.1,-1.65,.85)).normalized()*size*2.4);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*.92;scene.camera=cam
    for off,energy in [((.5,-.8,1.2),60),((-.7,-.2,.8),24)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(off)*size);o=bpy.context.object;o.data.energy=energy*size*size;o.data.size=size*.7;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.resolution_x=600;scene.render.resolution_y=500;scene.render.resolution_percentage=100
    scene.render.filepath=str(DEST/'blender'/(row['id']+'.png'));bpy.ops.render.render(write_still=True)

def build(row):
    random.seed(int(hashlib.sha256(row['id'].encode()).hexdigest()[:8],16));bpy.ops.wm.read_factory_settings(use_empty=True)
    B.M={k:B.material(k,B.rgb(c),rough=.82 if k=='bone' else (.27 if k=='eye' else .76),emit=.08 if k=='eye' else 0) for k,c in {'main':row['palette'][0],'secondary':row['palette'][1],'accent':row['palette'][2],'dark':'17272b','bone':'d5d3a5','eye':'e3ae4c'}.items()}
    B.BODY=B.pivot('Anim_Body');B.EYE_STYLE=row.get('eye_design','original')
    if row.get('collection')=='aberrant':A.construct(row['family'],row['morphology'])
    else:
        {'animal':B.make_animal,'plant':B.make_plant,'microbe':B.make_microbe}[row['category']](row['family'],row['morphology'])
        B.anatomy_variation(row['family'],row['category'],row['anatomy'])
    joint_shape(row)
    bpy.context.view_layer.update()
    # Ground the revised rest pose; preserve the authored child joint transforms.
    baseline=ROOT/row['source']
    pts=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box]
    B.BODY.location.z-=min(p.z for p in pts);bpy.context.view_layer.update()
    pivots={o.name:list(o.location)+list(o.rotation_euler)+list(o.scale) for o in bpy.context.scene.objects if o.type=='EMPTY'}
    editable=sum(o.type=='MESH' for o in bpy.context.scene.objects)
    bpy.context.scene.unit_settings.system='METRIC';bpy.ops.wm.save_as_mainfile(filepath=str(baseline))
    ink.consolidate_static_surfaces();outputs={};geometry={}
    for lod in ['near','far']:
        if lod=='far':
            for o in list(bpy.context.scene.objects):
                if o.type=='MESH' and len(o.data.polygons)>70:
                    bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('INK distant silhouette','DECIMATE');mod.ratio=.28;bpy.ops.object.modifier_apply(modifier=mod.name)
        p=B.OUT/(row['id']+'_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        tris=0
        for o in bpy.context.scene.objects:
            if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
        outputs[lod]={'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'triangles':tris}
        points=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
        game_points=[(p.x,p.z,-p.y) for p in points]
        low=[min(p[j] for p in game_points) for j in range(3)];high=[max(p[j] for p in game_points) for j in range(3)]
        geometry[lod]={'floor_y':low[1],'ceiling_y':high[1],'min':low,'max':high,'vertices':len(game_points)}
    # Render the editable near geometry, not the decimated export.
    bpy.ops.wm.open_mainfile(filepath=str(baseline));render_source(row)
    record=dict(row);record.update(lods=outputs,art_revision=REV,render_status='ink-life-exported-awaiting-game-review',generator='tools/build_ink_bestiary.py',editable_meshes=editable,motion_contract=pivots)
    record['geometry']=geometry
    (B.SRC/(row['id']+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    (DEST/'records'/(row['id']+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    current=json.loads(FORMS.read_text());current['forms']=[record if f['id']==row['id'] else f for f in current['forms']];FORMS.write_text(json.dumps(current,ensure_ascii=False,indent=2)+'\n')
    print('INK_LIFE_EXPORTED',row['id'],outputs['near']['triangles'],outputs['far']['triangles'],flush=True)

if __name__=='__main__':
    for row in BASE['forms']:
        if SELECT and row['id'] not in SELECT and row['family'] not in SELECT:continue
        record=DEST/'records'/(row['id']+'.json')
        if record.exists() and json.loads(record.read_text()).get('art_revision')==REV:
            print('INK_LIFE_RESUME_SKIP',row['id'],flush=True);continue
        build(row)
