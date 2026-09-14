"""Nine field facilities, editable Blender sources and consolidated production GLBs.
Blender --background --python tools/build_field_facilities.py -- [IDs]
Keeps existing placement envelopes, -Y service front and four process pivots.
"""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as g
import build_ink_followups as h
import ink_blender as ink
box,cyl,ring,rod,pipe,pivot=g.box,g.cyl,g.ring,g.rod,g.pipe,g.pivot
KINDS=['solar','charger','factory','storage','atmosphere','thermal','water','biolab','reactor']
REVIEW=ROOT/'docs/production/media/facility-design'
REVIEW.mkdir(parents=True,exist_ok=True)

def remove(*prefixes):
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(prefixes):bpy.data.objects.remove(o,do_unlink=True)

def chamfer(name,loc,size,role,cut=.2):
    x,y,z=size; c=min(cut,x*.3,y*.3)
    corners=[(-x/2+c,-y/2),(x/2-c,-y/2),(x/2,-y/2+c),(x/2,y/2-c),(x/2-c,y/2),(-x/2+c,y/2),(-x/2,y/2-c),(-x/2,-y/2+c)]
    verts=[(a+loc[0],b+loc[1],loc[2]+zz) for zz in [-z/2,z/2] for a,b in corners]
    faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    return g.finish(obj,name,role,.035)

def plinth():
    remove('Load bearing plinth','Inset service apron','Foundation anchor','Bearing plinth','Service apron')
    chamfer('Octagonal equipment chassis',(0,0,.20),(3.52,3.52,.28),'dark',.42)
    chamfer('Inset cast deck',(0,0,.355),(3.34,3.34,.075),'steel',.40)
    for x in [-1.43,1.43]:
        for y in [-1.43,1.43]:
            chamfer('Independent ground shoe',(x,y,.08),(.60,.60,.16),'dark',.13)
            cyl('Load screw',(x,y,.28),.10,.25,'steel')
            cyl('Anchor locking collar',(x,y,.44),.15,.11,'orange')
    for x in [-1.64,1.64]:
        box('Service skid sill',(x,0,.31),(.15,2.28,.30),'cream',.045)
        for y in [-.91,.91]:box('Skid coupling',(x,y,.32),(.18,.20,.33),'dark',.025)
    for x in [-.70,.70]:box('Fork insertion pocket',(x,-1.74,.19),(.37,.03,.14),'dark',.015)
    box('Front threshold',(0,-1.67,.40),(1.22,.14,.09),'orange',.018)

def valve(loc,scale=.18,axis=(math.pi/2,0,0)):
    ring('Service handwheel',loc,scale,.032,'orange',axis)
    cyl('Valve spindle',loc,.05,.18,'steel',axis)
    # Bars lie in front service plane.
    rod('Handwheel spoke',(loc[0]-scale,loc[1],loc[2]),(loc[0]+scale,loc[1],loc[2]),.025,'orange')
    rod('Handwheel spoke',(loc[0],loc[1],loc[2]-scale),(loc[0],loc[1],loc[2]+scale),.025,'orange')

def rear_service(height=1.3):
    for x in [-1.2,1.2]:
        rod('Service rail post',(x,1.52,.40),(x,1.52,height),.038,'steel')
    rod('Service guardrail',(-1.2,1.52,height),(1.2,1.52,height),.043,'orange')
    box('Power junction',(1.36,.93,.76),(.38,.54,.57),'teal',.065)
    cyl('Power input socket',(1.37,.63,.76),.12,.10,'dark',(math.pi/2,0,0))
    ring('Socket protector',(1.37,.57,.76),.105,.025,'orange',(math.pi/2,0,0))

def storage():
    chamfer('Cargo lower shell',(0,.06,.96),(2.9,2.8,1.13),'teal',.28)
    chamfer('Cargo roof gasket',(0,.06,1.57),(2.98,2.88,.12),'dark',.30)
    chamfer('Tapered cargo lid',(0,.06,1.72),(3.04,2.94,.22),'cream',.34)
    for side in [-1,1]:
        x=side*1.36
        for y in [-1.21,1.21]:
            box('Vertical stacking corner',(x,y,1.02),(.24,.26,1.20),'cream',.065)
            box('Lifting corner',(x,y,1.82),(.29,.31,.22),'steel',.04)
        for z in [.74,1.06,1.35]:box('Side inset rib',(side*1.465,.13,z),(.06,1.67,.10),'dark',.025)
        pipe('Recessed lifting handle',[(side*1.46,-.72,1.21),(side*1.56,-.72,1.38),(side*1.56,-.22,1.38),(side*1.46,-.22,1.21)],.035,'orange')
    for x in [-.67,.67]:
        box('Cargo door recess',(x,-1.365,1.05),(1.23,.10,1.02),'dark',.08)
        chamfer('Cargo loading door',(x,-1.43,1.06),(1.09,.12,.91),'cream',.13)
        box('Door central armour',(x,-1.51,1.09),(.88,.05,.56),'teal',.055)
        for z in [.73,1.36]:box('Door barrel hinge',(x-.47,-1.525,z),(.14,.11,.19),'steel',.04)
        box('Latch housing',(x+.33,-1.55,1.08),(.13,.10,.28),'dark',.02)
        box('Cam lock handle',(x+.33,-1.61,1.08),(.07,.05,.19),'orange',.02)
    for x in [-.82,.82]:box('Stacking roof runner',(x,.02,1.89),(.17,2.10,.13),'dark',.04)
    box('Inventory status recess',(0,-1.58,1.70),(.55,.035,.11),'dark',.016)
    for x in [-.18,0,.18]:box('Cargo status segment',(x,-1.61,1.70),(.10,.02,.05),'status',.01)

def solar():
    h.solar()
    remove('Rounded panel backplate','Inset cell substrate','Photovoltaic module','Module busbar','Outer load rail','Array support strut','Panel bearing')
    box('Azimuth drive yoke',(0,0,1.44),(.65,.91,.43),'cream',.08)
    cyl('Panel pitch bearing',(0,0,1.70),.21,.84,'dark',(math.pi/2,0,0))
    for side in [-1,1]:
        # Two separated, pitched wings create a recognizable collector silhouette.
        group=pivot('Collector_Wing_'+str(side),(side*.13,0,1.80))
        parts=[]
        o=chamfer('Collector wing perimeter',(side*1.07,0,1.90),(1.89,2.75,.16),'cream',.16);parts.append(o)
        parts.append(box('Wing dark substrate',(side*1.07,0,2.0),(1.71,2.55,.055),'dark',.025))
        for x in [side*.63,side*1.49]:
            for y in [-.86,0,.86]:
                parts.append(box('Silicon cell module',(x,y,2.052),(.78,.78,.055),'solar_cell',.025))
                parts.append(box('Cell conductor',(x,y,2.084),(.63,.013,.006),'steel',.002))
        for y in [-1.05,1.05]:parts.append(rod('Wing spar',(side*.18,y,1.78),(side*1.91,y,1.78),.055,'steel'))
        for o in parts:
            mat=o.matrix_world.copy();o.parent=group;o.matrix_world=mat
        group.rotation_euler.y=side*math.radians(-13)
        rod('Hydraulic wing brace',(side*.23,0,1.1),(side*1.64,0,2.06),.065,'steel')
        cyl('Wing hinge cap',(side*.13,-.53,1.80),.145,.12,'orange',(math.pi/2,0,0))
    box('Forward converter cover',(0,-.76,.67),(.95,.76,.57),'cream',.1)
    for x in [-.27,0,.27]:box('Converter ventilation',(x,-1.16,.70),(.12,.025,.25),'dark',.012)

def charger():
    h.charger()
    remove('Charger terminal foot','Charging power pedestal','Terminal collar','Charging display','Charging state bar')
    for x in [-1.30,1.30]:
        chamfer('Dock shoulder',(x,.05,.90),(.46,2.48,.93),'cream',.14)
        box('Dock rail inset',(x,-.02,1.37),(.27,1.87,.06),'teal',.02)
        for y in [-.65,.10,.78]:box('Dock shoulder status',(x,y,1.41),(.10,.22,.025),'status',.01)
    chamfer('Rear transformer block',(0,1.18,1.23),(2.2,.63,1.65),'teal',.24)
    chamfer('Rear protective canopy',(0,1.18,2.11),(2.5,.80,.18),'cream',.24)
    for x in [-.63,.63]:
        box('Transformer heat recess',(x,.841,1.45),(.69,.04,.67),'dark',.045)
        for z in [1.22,1.43,1.64]:box('Transformer cooling fin',(x,.80,z),(.57,.09,.075),'steel',.02)
    pipe('Dock charging loom',[(.80,1.08,1.05),(.95,.78,.77),(.83,.56,.61)],.07,'rubber')
    box('Dock front ramp',(0,-1.37,.48),(1.58,.45,.19),'steel',.045)

def factory():
    h.factory()
    remove('Overhead gantry','Front gantry identity plate','Pod front inset','Safety handle')
    # Open view into the assembly cell, distinct high roof with transverse ribs.
    for y in [-1.27,.82]:
        for side in [-1,1]:
            rod('Gantry buttress',(side*1.32,y,2.32),(side*.94,y,3.24),.16,'cream')
        box('Gantry crown',(0,y,3.28),(2.05,.31,.32),'cream',.09)
    for x in [-.94,.94]:box('Roof backbone',(x,-.16,3.22),(.20,2.33,.20),'teal',.05)
    chamfer('Roof control pod',(0,.49,3.48),(1.48,.74,.28),'teal',.18)
    for x in [-1.13,1.13]:
        chamfer('Armoured service door',(x,-1.31,1.63),(.53,.18,1.64),'teal',.15)
        box('Door release latch',(x,-1.43,1.64),(.085,.10,.39),'orange',.025)
    for side in [-1,1]:
        x=side*.56
        cyl('Manipulator shoulder',(x,.49,1.22),.14,.30,'orange',(0,math.pi/2,0))
        rod('Manipulator upper arm',(x,.49,1.22),(x,.13,1.62),.075,'cream')
        cyl('Manipulator elbow',(x,.13,1.62),.105,.20,'dark',(0,math.pi/2,0))
        rod('Manipulator wrist',(x,.13,1.62),(x*.55,-.15,1.42),.056,'steel')
    box('Bay header identifier',(0,-1.46,3.26),(.71,.06,.13),'teal',.025)

def atmosphere():
    g.atmosphere()
    remove('Filter cassette','Cassette latch','Air transfer duct','Weather hood')
    # Service column is wrapped by two arched intake ducts, not a bare cylinder.
    for x in [-1.16,.23]:
        pipe('Formed intake trunk',[(x,-.31,.60),(x,-.70,1.07),(x,-.71,2.28),(x,-.12,2.95)],.20,'teal')
        ring('Duct compression collar',(x,-.66,1.12),.215,.035,'steel')
    for z in [1.20,1.85,2.50]:
        chamfer('Removable separation cassette',(-.45,-.74,z),(.78,.22,.40),'cream',.10)
        box('Cassette inspection slit',(-.45,-.875,z),(.42,.035,.075),'dark',.02)
    chamfer('Wind deflector canopy',(-.45,.15,3.74),(1.64,1.46,.22),'cream',.31)
    box('Deflector support',(-.45,.60,3.54),(.30,.28,.35),'teal',.04)
    pipe('Fan manifold',[(1.18,.35,1.65),(1.05,.99,1.71),(.05,.98,2.21)],.15,'steel')
    rear_service(1.3)

def thermal():
    g.thermal()
    remove('Radiator header','Radiator side armour','Fin leading shield')
    # Two triangular load braces frame the exchanger with a broken top silhouette.
    for side in [-1,1]:
        x=-.43+side*.82
        rod('Radiator inclined support',(x,-.27,.48),(x,.39,3.58),.11,'cream')
        box('Radiator corner shoe',(x,-.20,.57),(.33,.55,.29),'teal',.06)
    chamfer('Exchanger upper manifold',(-.43,.24,3.48),(1.93,1.19,.27),'cream',.23)
    chamfer('Exchanger lower manifold',(-.43,.10,.59),(1.80,1.22,.23),'teal',.2)
    for z in [.86,1.28,1.70,2.12,2.54,2.96]:box('Broad radiating plate nose',(-.43,-.50,z),(1.32,.10,.065),'teal',.015)
    for x in [-.94,.07]:
        pipe('Exchanger return header',[(x,.94,.58),(x,1.14,1.52),(x,1.05,3.21)],.095,'steel')
    valve((-.43,-.69,.73),.13)
    rear_service(1.14)

def water():
    g.water()
    remove('Water receiver','Receiver inspection recess','Water level window','Level graduation','Filter cartridge','Filter outlet')
    # Horizontal receiver on saddles breaks the repeated upright-tank silhouette.
    for y in [-.62,.73]:
        chamfer('Receiver support saddle',(-.49,y,.94),(1.84,.23,1.06),'dark',.28)
    cyl('Horizontal receiver barrel',(-.49,.15,1.85),.83,1.78,'teal',(math.pi/2,0,0))
    for y in [-.77,1.07]:
        h.uv('Dished receiver cap',(-.49,y,1.85),(.82,.20,.82),'cream')
        ring('Receiver pressure flange',(-.49,y,1.85),.81,.045,'steel',(math.pi/2,0,0))
    cyl('Receiver inspection plug',(-.49,-.99,1.85),.30,.11,'dark',(math.pi/2,0,0))
    cyl('Receiver liquid sight',(-.49,-1.058,1.85),.24,.035,'water',(math.pi/2,0,0))
    for x in [-1.00,-.43,.13]:
        g.vessel('Vertical filter cartridge',(x,-1.05,1.05),.16,.89,'cream')
    pipe('Filter collector',[(-1,-1.05,.58),(-.43,-1.05,.52),(.13,-1.05,.58),(.30,-.75,1.16)],.057,'steel')
    valve((-.49,-1.15,2.36),.15)
    rear_service(1.07)

def biolab():
    g.biolab()
    remove('Chamber protective upright','Ceramic chamber roof')
    # Faceted structural cage and sloped shoulders protect the visible culture.
    for i in range(6):
        a=i*math.tau/6; x,y=math.cos(a),math.sin(a)
        rod('Biolab cage foot',(x*1.13,y*1.13,.57),(x*1.13,y*1.13,1.48),.075,'teal')
        rod('Glazing mullion',(x*1.13,y*1.13,1.48),(x,y,2.82),.045,'cream')
    cyl('Culture roof seal',(0,0,2.87),1.06,.16,'dark')
    cyl('Raised culture roof',(0,0,2.96),1.14,.13,'cream')
    for x in [-1.33,1.33]:
        chamfer('Nutrient protection pod',(x,.60,.81),(.49,.72,.84),'teal',.14)
        box('Pod nutrient gauge',(x,.225,.86),(.18,.03,.28),'status',.02)
    for y in [.48,.86,1.24]:box('Rear ventilation fin',(0,y,1.03),(1.37,.11,.10),'steel',.015)
    rear_service(1.42)

def reactor():
    h.reactor()
    remove('Faceted containment core','Containment emitter','Field terminal','Containment load arm')
    h.uv('Contained plasma vessel',(0,0,2.81),(.48,.48,.83),'reactor_core')
    for i in range(4):
        a=math.pi*.25+i*math.pi/2; x,y=math.cos(a),math.sin(a)
        rod('Reactor buttress',(x*1.18,y*1.18,.57),(x*.97,y*.97,3.48),.13,'cream')
        cyl('Upper coil actuator',(x*.97,y*.97,3.28),.16,.68,'teal')
        rod('Containment contact',(x*.97,y*.97,3.48),(x*.58,y*.58,3.48),.055,'orange')
    for z in [2.20,3.45]:
        ring('Encircling induction yoke',(0,0,z),1.04,.11,'teal')
        ring('Coil retaining lip',(0,0,z+.11),1.04,.036,'steel')
    for x in [-1.18,1.18]:
        chamfer('Cooling pump pod',(x,.76,1.0),(.61,.86,1.19),'teal',.18)
        pipe('Reactor coolant loop',[(x,.76,1.47),(x,1.02,1.76),(x*.46,1.0,1.91)],.065,'steel')

def review(kind):
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Facility studio');scene.world.color=(.18,.18,.18)
    box('Review ground',(0,0,-.07),(200,200,.1),'cream',0)
    center=Vector((0,0,1.55))
    bpy.ops.object.camera_add(location=(6.5,-8,6.0));camera=bpy.context.object
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=6.1;scene.camera=camera
    for loc,power,size in [((3,-5,8),1500,5),((-4,-1,5),800,4)]:
        bpy.ops.object.light_add(type='AREA',location=loc);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=12
    scene.render.resolution_x=900;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.filepath=str(REVIEW/(kind+'-blender.png'));bpy.ops.render.render(write_still=True)

def build(wanted):
    if set(wanted)-set(KINDS):raise SystemExit('Unknown facility ID')
    manifest_path=ROOT/'art/blender/manifest.json';manifest=json.loads(manifest_path.read_text())
    report=REVIEW/'geometry.json'
    output=json.loads(report.read_text()) if report.exists() else []
    for kind in wanted:
        g.reset();globals()[kind]();plinth()
        bpy.context.scene.unit_settings.system='METRIC';bpy.context.view_layer.update()
        pivots={o.name:[list(row) for row in o.matrix_world] for o in bpy.context.scene.objects if o.name.startswith('Anim_')}
        editable=sum(o.type=='MESH' for o in bpy.context.scene.objects)
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender'/f'{kind}.blend'))
        exported=ink.consolidate_static_surfaces();bpy.context.view_layer.update()
        for name,mat in pivots.items():assert all(abs(a-b)<1e-6 for r1,r2 in zip(mat,bpy.data.objects[name].matrix_world) for a,b in zip(r1,r2)),name
        bpy.ops.export_scene.gltf(filepath=str(ROOT/'우주-비즈니스/assets/models'/f'{kind}.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
        triangles=0
        for o in bpy.context.scene.objects:
            if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
        row={'id':kind,'generator':'tools/build_field_facilities.py','geometry':'field-industry-refined','editable_objects':editable,'export_objects':exported,'triangles':triangles,'motion_pivots':pivots,'blender':bpy.app.version_string}
        output=[r for r in output if r["id"]!=kind]+[row]
        for existing in manifest:
            if existing['id']==kind:existing.update(row)
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        (REVIEW/'geometry.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
        print('FACILITY_EXPORTED',kind,editable,exported,triangles,flush=True)
        review(kind)
if __name__=='__main__':
    build(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else KINDS)
