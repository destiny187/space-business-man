"""Nine walkable INK cabins; shared safe deck, role-authored architecture.

Coordinates below use Godot XYZ. Window panes are real apertures, exported under
WindowPanes for the game's single screen-projected exterior pass.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import ink_blender as ink
SOURCE = ROOT/'art/blender/crew/interiors'
OUTPUT = ROOT/'우주-비즈니스/assets/models/crew/interiors'
CAPTURE = ROOT/'output/vessel-interiors/blender'
for path in (SOURCE, OUTPUT, CAPTURE): path.mkdir(parents=True, exist_ok=True)
HULLS = [('kestrel','explorer',1),('swift','interceptor',1),('mule','hauler',1),
         ('aster','explorer',3),('peregrine','interceptor',3),('ox','hauler',3),
         ('orion','explorer',5),('spectre','interceptor',5),('atlas','hauler',5)]

def xyz(p): return (p[0], -p[2], p[1])
def empty(name, p=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=xyz(p);bpy.context.view_layer.update()
    return o
def custom(name, color, emission=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    m.diffuse_color=(*color,1);s=m.node_tree.nodes['Principled BSDF']
    s.inputs['Base Color'].default_value=(*color,1);s.inputs['Roughness'].default_value=.4
    s.inputs['Emission Color'].default_value=(*color,1);s.inputs['Emission Strength'].default_value=emission
    return m
def finish(o,name,role,bevel=.035,parent=None):
    o.name=name;o.data.materials.append(ink.material(role) if isinstance(role,str) else role)
    ink.manufactured_edges(o,bevel,3)
    if parent:
        o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
    return o
def box(name,p,size,role='enamel_cream',bevel=.04,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,role,bevel,parent)
def beam(name,a,b,width,role='enamel_teal',parent=None):
    aa,bb=Vector(xyz(a)),Vector(xyz(b));d=bb-aa
    bpy.ops.mesh.primitive_cube_add(size=1,location=(aa+bb)/2);o=bpy.context.object
    o.scale=(width,width,d.length);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return finish(o,name,role,min(width*.23,.065),parent)
def cylinder(name,p,radius,depth,role='edge_steel',parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=xyz(p))
    return finish(bpy.context.object,name,role,.025,parent)
def ring(name,p,radius,role='edge_steel',parent=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=10,location=xyz(p),major_radius=radius,minor_radius=.055)
    return finish(bpy.context.object,name,role,0,parent)
def pane(name,points,parent):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([xyz(p) for p in points],[],[tuple(range(len(points)))]);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    finish(o,name,custom('Observation aperture',(.017,.052,.085),.4),0,parent)
def seat(x,z,role,tier,glow):
    cylinder('Seat suspension',(x,.28,z),.27,.5)
    box('Seat pressure cushion',(x,.63,z),(.89,.22,.87),'rubber',.10)
    back=box('Bucket seat shell' if role=='interceptor' else 'Crew seat shell',(x,1.19,z+.4),(.97,1.22,.24),'structural_dark' if role=='interceptor' else ('enamel_cream' if role=='hauler' else 'enamel_teal'),.13)
    if role=='interceptor':back.rotation_euler.x=.13
    box('Head support',(x,1.76,z+.35),(.65,.30,.27),'rubber',.10)
    box('Lumbar cushion',(x,1.15,z+.245),(.68,.56,.10),'rubber',.05)
    for s in (-1,1):
        box('Harness',(x+s*.29,1.21,z+.17),(.06,.76,.04),'safety_orange',.012)
        box('Arm support',(x+s*.5,.93,z),(.12,.17,.73),'enamel_cream',.055)
        if tier>=3:box('Seat shoulder bolster',(x+s*.42,1.47,z+.17),(.15,.42,.31),'enamel_cream',.065)
    box('Seat status',(x,1.93,z+.4),(.3,.055,.06),glow,.013)
    if role=='interceptor':
        for s in (-1,1):
            beam('Racing bucket shoulder',(x+s*.36,1.1,z+.56),(x+s*.51,1.82,z+.30),.17,'enamel_cream')
            box('Acceleration restraint',(x+s*.40,1.49,z+.22),(.16,.50,.23),'safety_orange',.065)
        box('Bucket spine',(x,1.23,z+.55),(.32,.88,.13),'enamel_teal',.06)
    elif role=='hauler':
        for s in (-1,1):
            beam('Seat cargo roll cage',(x+s*.51,.39,z+.54),(x+s*.51,1.75,z+.54),.10,'edge_steel')
        beam('Seat cage bridge',(x-.51,1.75,z+.54),(x+.51,1.75,z+.54),.1,'edge_steel')
        box('Seat service hatch',(x,1.22,z+.57),(.59,.61,.12),'enamel_teal',.055)
        box('Fold release',(x,.79,z+.65),(.34,.11,.08),'safety_orange',.025)
    elif tier>=3:
        box('Survey seat backplate',(x,1.2,z+.56),(.72,.70,.10),'enamel_cream',.11)
        for s in (-1,1):box('Seat analytic strip',(x+s*.18,1.23,z+.622),(.065,.36,.025),glow,.012)

def build(name,role,tier):
    height=(4.3 if role=='interceptor' else 4.6)+(tier-1)*.14
    glow=custom('Cabin teal light',(.18,.68,.60),1.7)
    amber=custom('Cabin amber light',(.85,.33,.07),1.1)
    screen=custom('Instrument glass',(.015,.085,.105),.3)
    panes=empty('WindowPanes')
    box('Pressure deck',(0,-.23,0),(8,.46,16),'structural_dark',.09)
    for z in range(-7,8,2):
        box('Central removable deck',(0,-.015,z),(3.65,.1,1.94),'edge_steel',.04)
        for s in (-1,1):
            box('Side deck',(s*2.94,-.015,z),(2.03,.1,1.94),'enamel_teal',.04)
            box('Lit aisle guide',(s*1.73,.045,z),(.038,.014,1.45),glow,.004)
    for s in (-1,1):
        x=s*3.99
        box('Lower pressure hull',(x,.51,0),(.26,1.1,16),'structural_dark',.055)
        box('Lower ceramic liner',(s*3.79,.64,0),(.16,.79,15.8),'enamel_cream',.065)
        box('Long service conduit',(s*3.61,.25,0),(.19,.21,15.8),'edge_steel')
        box('Window brow',(s*3.96,height-.19,0),(.31,.38,16),'enamel_teal',.06)
        for z in (-6.4,-3.2,0,3.2,6.4):
            lo=1.25 if role=='hauler' else 1.06
            hi=height-.42
            pane('Port panorama' if s<0 else 'Starboard panorama',[(x,lo,z-1.43),(x,lo,z+1.43),(x,hi,z+1.43),(x,hi,z-1.43)],panes)
            if role=='hauler':box('Cargo window armor sill',(s*3.78,1.09,z),(.22,.36,2.95),'enamel_teal')
            ribz=z-1.55
            if role=='interceptor':
                beam('Swept canopy rib',(s*3.77,.95,ribz),(s*3.80,height-.18,ribz+.66),.19)
            else:beam('Pressure arch leg',(s*3.77,.94,ribz),(s*3.77,height-.16,ribz),.22 if role=='explorer' else .30)
            box('Window rail lamp',(s*3.67,height-.40,z),(.08,.08,2.15),glow,.016)
        for z in (-4,-1,2):seat(s*2.65,z,role,tier,glow)
    # Segmented roof with actual skylights. Haulers carry two load rails around them.
    roof_width=2.9 if role=='interceptor' else (3.5 if role=='explorer' else 2.5)
    for z in (-6.4,-3.2,0,3.2,6.4):
        for s in (-1,1):
            box('Shoulder ceiling liner',(s*(2+roof_width*.25),height,z),((8-roof_width)*.5,.18,3.06),'enamel_cream',.06)
        pane('Zenith observation', [(-roof_width/2,height,z-1.42),(roof_width/2,height,z-1.42),(roof_width/2,height,z+1.42),(-roof_width/2,height,z+1.42)],panes)
        box('Roof arch',(0,height-.09,z-1.55),(7.95,.22,.22),'enamel_teal',.055)
    box('Panoramic sill',(0,.51,-7.93),(8,1.05,.32),'enamel_teal',.07)
    box('Panoramic visor header',(0,height-.14,-7.93),(8,.3,.35),'enamel_cream',.06)
    pane('Forward panorama',[(-3.82,1.04,-7.96),(3.82,1.04,-7.96),(3.82,height-.3,-7.96),(-3.82,height-.3,-7.96)],panes)
    for s in (-1,1):
        beam('Forward angled mullion',(s*2.65,1.03,-7.76),(s*3.1,height-.28,-7.76),.105,'edge_steel')
        box('Avionics pedestal',(s*2.7,.59,-6.6),(1.52,1.18,.88),'structural_dark',.12)
        panel=box('Cantilevered flight console',(s*2.7,1.26,-6.6),(1.72,.20,1.08),'enamel_teal',.1)
        panel.rotation_euler.x=.16
        box('Glass instrument surface',(s*2.7,1.4,-6.71),(1.35,.045,.53),screen,.025)
        for k in range(4):box('Instrument telemetry',(s*2.7+(k-1.5)*.26,1.431,-6.72),(.14,.011,.10+k*.055),glow,.008)
        for dx in (-.51,-.26,0,.26,.51):box('Flight control',(s*2.7+dx,1.4,-6.24),(.14,.05,.14),'safety_orange' if dx==0 else 'enamel_cream',.018)
    # Common aft service footprint preserves six spawn positions and both devices.
    box('Aft pressure bulkhead',(0,height/2,7.98),(8,height,.25),'enamel_cream',.07)
    box('Airlock gasket',(0,1.6,7.79),(2.55,3.2,.15),'structural_dark',.14)
    for s in (-1,1):
        box('Pressure door',(s*.55,1.52,7.66),(1.04,2.95,.16),'enamel_teal',.1)
        box('Airlock lever',(s*.35,1.38,7.52),(.1,.45,.12),'safety_orange',.035)
        box('Service bay surround',(s*3.0,2.65,5.20),(1.7,.18,2.0),'enamel_teal')
        box('Service bay status',(s*3,2.53,5.06),(1.24,.065,.09),glow,.013)
    box('Communal locker',(0,.59,5.6),(1.7,1.18,.85),'enamel_teal',.12)
    box('Sealed locker lid',(0,1.22,5.6),(1.81,.15,.94),'enamel_cream',.055)
    for x in (-.48,.48):box('Locker latch',(x,.93,5.13),(.19,.27,.07),'safety_orange',.024)
    # Role/tier architecture: articulated overhead assemblies stay above headroom.
    if role=='explorer':
        # Curved pressure ribs give the observatory a vaulted silhouette.
        for z in (-4.75,-1.55,1.65,4.85):
            for s in (-1,1):
                points=[(s*3.74,3.08,z),(s*3.66,3.38,z),(s*3.38,height-.75,z),(s*2.96,height-.38,z),(s*2.38,height-.17,z),(s*1.65,height-.13,z)]
                for a,b in zip(points,points[1:]):beam('Vaulted survey arch',a,b,.18 if tier==1 else .24,'enamel_cream')
        for s in (-1,1):
            for z in ((-4.9,.8) if tier<5 else (-4.9,-1.8,.8)):
                cylinder('Suspended survey pod',(s*2.75,height-.72,z),.36,.75,'enamel_cream')
                cylinder('Survey optic',(s*2.75,height-1.13,z),.26,.06,glow)
                for dx in (-.42,.42):
                    beam('Optic gimbal fork',(s*2.75+dx,height-.16,z),(s*2.75+dx,height-.75,z),.10,'edge_steel')
                    beam('Optic gimbal pin',(s*2.75+dx,height-.75,z),(s*2.75,height-.75,z),.10,'edge_steel')
        if tier>=3:
            rotor=empty('Anim_ObservationRing',(0,height-.50,-3.5))
            ring('Astrometric ring',(0,height-.50,-3.5),1.00 if tier==3 else 1.48,'edge_steel',rotor)
            for n in range(6 if tier==3 else 10):
                a=n*math.tau/(6 if tier==3 else 10);r=1 if tier==3 else 1.48
                box('Sensor on ring',(math.cos(a)*r,height-.49,-3.5+math.sin(a)*r),(.18,.17,.25),'enamel_teal',.035,rotor)
            if tier==5:
                ring('Deep field lens crown',(0,height-.70,-3.5),.65,glow)
                for s in (-1,1):beam('Suspension fork',(s*2.2,height,-3.5),(s*1.3,height-.5,-3.5),.12)
    elif role=='interceptor':
        for s in (-1,1):
            for z in (-6.0,-2.8,.4,3.6):
                beam('Canopy diagonal shoulder',(s*3.78,3.08,z),(s*2.12,height-.16,z+.48),.19,'structural_dark')
                if tier>=3:beam('Canopy shoulder lighting',(s*3.66,3.22,z-.025),(s*2.19,height-.20,z+.41),.055,glow)
        for s in (-1,1):
            for z in (-4.6,-1.4,1.8):
                beam('Swept ceiling spine',(s*3.4,height-.32,z-1.2),(s*1.7,height-.19,z+.6),.15,'structural_dark')
                if tier>=3:beam('Vector conduit',(s*3.15,height-.45,z-1.1),(s*1.85,height-.3,z+.4),.07,glow)
        if tier==5:
            for s in (-1,1):
                for z in (-5.1,-2.5,.1):
                    box('Phase core guard',(s*3.44,3.35,z),(.32,.32,.75),'structural_dark',.06)
                    box('Phase core',(s*3.32,3.35,z),(.13,.14,.49),glow,.035)
        compass=empty('Anim_VectorCompass',(0,height-.47,-6.2))
        ring('Flight vector ring',(0,height-.47,-6.2),.6+.1*tier,'edge_steel',compass)
    else:
        for s in (-1,1):
            box('Overhead cargo gantry',(s*1.60,height-.42,0),(.30,.42,15.2),'edge_steel',.045)
            for z in (-4.8,-1.6,1.6):
                box('Secured utility case',(s*3.53,3.38,z),(.36,.72,.91),'enamel_teal',.08)
                box('Case locking latch',(s*3.30,3.39,z),(.08,.15,.27),'safety_orange',.02)
            for z in ((-.3,) if tier==1 else (-3.5,-.3,2.9)):
                box('Ceiling secured cargo locker',(s*2.88,height-.50,z),(1.03,.68,1.65),'enamel_teal',.11)
                box('Cargo locker underside',(s*2.88,height-.87,z),(.80,.085,1.39),'enamel_cream',.05)
                for dz in (-.67,.67):
                    box('Ceiling cargo restraint',(s*2.88,height-.53,z+dz),(1.10,.83,.12),'edge_steel',.028)
                box('Ceiling cargo clamp',(s*2.30,height-.49,z),(.09,.21,.32),'safety_orange',.026)
        if tier>=3:
            trolley=empty('Anim_GantryTrolley',(0,height-.5,-3.4))
            box('Gantry carriage',(0,height-.5,-3.4),(3.65,.25,.75),'structural_dark',.07,trolley)
            cylinder('Crane drive',(0,height-.76,-3.4),.4,.36,'enamel_teal',trolley)
            for s in (-1,1):box('Cargo clamp',(s*.43,height-.98,-3.4),(.22,.45,.40),'safety_orange',.05,trolley)
        if tier==5:
            for s in (-1,1):
                for z in (-6.25,3.15):beam('Armored load brace',(s*3.65,3.12,z),(s*1.7,height-.3,z),.25,'enamel_cream')
            box('Freight control balcony',(0,height-.15,6.9),(6.9,.40,1.45),'enamel_teal',.10)
    bpy.ops.object.text_add(location=xyz((0,3.35,7.78)),rotation=(math.pi/2,0,0))
    label=bpy.context.object;label.name='Aft hull registry';label.data.body=name.upper();label.data.align_x='CENTER';label.data.size=.34
    label.data.extrude=.002;label.data.materials.append(ink.material('structural_dark'));bpy.ops.object.convert(target='MESH')
    return height

def studio(height):
    scene=bpy.context.scene;world=bpy.data.worlds.new('Cabin inspection');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.08,.13,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
    for z in (-5,0,5):
        bpy.ops.object.light_add(type='AREA',location=xyz((0,height-.22,z)));lamp=bpy.context.object
        lamp.data.energy=350;lamp.data.shape='DISK';lamp.data.size=4
    bpy.ops.object.camera_add(location=xyz((0,1.8,3.6)));camera=bpy.context.object
    camera.rotation_euler=(Vector(xyz((0,2.3,-6.8)))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=18;scene.camera=camera
    scene.render.engine='BLENDER_EEVEE';scene.eevee.use_raytracing=True
    scene.eevee.fast_gi_method='AMBIENT_OCCLUSION_ONLY';scene.eevee.fast_gi_distance=3.0
    scene.eevee.taa_render_samples=32
    scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX'

def main():
    selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    rows=[];definitions={}
    for name,role,tier in HULLS:
        height=(4.3 if role=='interceptor' else 4.6)+(tier-1)*.14
        definitions[name]={'model':f'res://assets/models/crew/interiors/{name}.glb','role':role,'tier':tier,'height':height,'light_color':'e3edcd' if role=='explorer' else ('b9e7ed' if role=='interceptor' else 'ffe1b5')}
        if selected and name not in selected:continue
        bpy.ops.wm.read_factory_settings(use_empty=True);build(name,role,tier);studio(height)
        bpy.context.scene.unit_settings.system='METRIC'
        source=SOURCE/(name+'.blend');output=OUTPUT/(name+'.glb')
        bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces()
        bpy.ops.object.select_all(action='DESELECT')
        for o in bpy.context.scene.objects:
            if o.type in ('MESH','EMPTY'):o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True)
        bpy.context.scene.render.filepath=str(CAPTURE/(name+'.png'));bpy.ops.render.render(write_still=True)
        triangles=0
        for o in bpy.context.scene.objects:
            if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
        rows.append({'id':name+'_interior','source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),'triangles':triangles,'role':role,'tier':tier,'windows':16,'style':'ink-v1'})
        print('INTERIOR_EXPORTED',name,triangles,flush=True)
    manifest=SOURCE/'manifest.json';existing=json.loads(manifest.read_text()) if manifest.exists() else []
    manifest.write_text(json.dumps([r for r in existing if r['id'] not in [x['id'] for x in rows]]+rows,ensure_ascii=False,indent=2)+'\n')
    config={'version':1,'fallback':'kestrel','hulls':definitions,'window_origin':[0,2,-18],
            'collisions':[{'position':[0,-.25,0],'size':[8,.5,16]},{'position':[0,.6,5.6],'size':[1.85,1.3,1]}]}
    for s in (-1,1):
        config['collisions'] += [{'position':[s*3.9,2.7,0],'size':[.3,5.4,16]}, {'position':[0,2.7,s*7.9],'size':[8,5.4,.3]}, {'position':[s*2.7,.8,-6.6],'size':[1.8,1.6,1.2]}]
        config['collisions'] += [{'position':[s*2.65,.9,z],'size':[1.18,1.8,1.2]} for z in (-4,-1,2)]
    (ROOT/'우주-비즈니스/data/vessel_interiors.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
