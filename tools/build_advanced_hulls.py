"""Six role-authored expedition hulls. Blender +Y forward / Godot -Z.

Editable industrial assemblies, shared INK materials, independent radiator pivots,
and actual exhaust sockets. No existing hull is overwritten.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as ink
SOURCE = ROOT / 'art/blender/ships/advanced'
OUTPUT = ROOT / '우주-비즈니스/assets/models/ships'
CAPTURE = ROOT / 'output/advanced-hulls/blender'
for folder in (SOURCE, OUTPUT, CAPTURE):
    folder.mkdir(parents=True, exist_ok=True)

def finish(obj, name, role, bevel=.055, parent=None):
    obj.name = name
    obj.data.materials.append(ink.material(role))
    ink.manufactured_edges(obj, bevel, 3)
    if parent: obj.parent = parent
    return obj

def empty(name, at, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = at
    if parent: obj.parent = parent
    return obj

def box(name, at, size, role='enamel_cream', bevel=.07, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object; obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, role, bevel, parent)

def cylinder(name, at, radius, depth, role='edge_steel', axis='Y', parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth,
                                      location=at, rotation=(math.pi/2,0,0) if axis=='Y' else (0,0,0))
    return finish(bpy.context.object, name, role, min(.05, depth*.15), parent)

def loft(name, sections, role='enamel_cream', x=0, parent=None):
    profile = [(-.72,1),(.72,1),(1,.48),(1,-.48),(.72,-1),(-.72,-1),(-1,-.48),(-1,.48)]
    vertices = [(x+u*w,y,z+v*h) for y,w,h,z in sections for u,v in profile]
    faces = []
    for i in range(len(sections)-1):
        for j in range(8):
            a=i*8+j; faces.append((a,i*8+(j+1)%8,(i+1)*8+(j+1)%8,a+8))
    faces += [tuple(reversed(range(8))),tuple((len(sections)-1)*8+j for j in range(8))]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    return finish(obj,name,role,.10,parent)

def wing(name, outline, z, thickness=.32, role='enamel_cream'):
    count=len(outline)
    vertices=[(x,y,z+dz) for dz in (-thickness/2,thickness/2) for x,y in outline]
    faces=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,role,.08)

def cockpit(nose=5.4, width=1.65, height=1.1):
    loft('Pressure cockpit',[(nose-5,width,.55,height),(nose-2,width*.92,.67,height),(nose,.7,.3,height-.35)],'structural_dark')
    loft('Armored cockpit brow',[(nose-4.8,width+.1,.13,height+.5),(nose-2,width,.13,height+.66),(nose-1.85,width*.93,.09,height+.65)],'enamel_cream')
    loft('Inset panoramic visor',[(nose-1.75,width*.85,.24,height+.38),(nose-.02,.63,.21,height-.02)],'enamel_teal')
    for s in (-1,1):
        strip=box('Windshield mullion',(s*.65,nose-1,height+.45),(.065,1.8,.08),'edge_steel',.02)
        strip.rotation_euler.x=-.35

def engine(x,y,z,radius=1.0):
    side='L' if x<0 else 'R'
    loft('Engine armored nacelle',[(y-2.2,radius,.8*radius,z),(y-1.8,1.1*radius,radius,z),(y+1.3,radius,radius,z),(y+2.2,.7*radius,.7*radius,z)],'enamel_cream',x)
    for offset in (-1.5,1.2): cylinder('Nacelle reinforcement',(x,y+offset,z),radius*1.03,.18,'enamel_teal')
    cylinder('Recessed intake',(x,y+2.25,z),radius*.62,.14,'structural_dark')
    for i in range(4):box('Intake guard',(x+(i-1.5)*radius*.23,y+2.34,z),(.07,.08,radius*.95),'edge_steel',.01)
    nozzle=empty('Anim_Nozzle_'+side,(x,y-2.2,z))
    cylinder('Exhaust shroud',(0,-.22,0),radius*.93,.62,'structural_dark',parent=nozzle)
    cylinder('Nozzle lip',(0,-.56,0),radius*.98,.14,'edge_steel',parent=nozzle)
    cylinder('Ion throat',(0,-.65,0),radius*.68,.08,'enamel_teal',parent=nozzle)
    empty('Socket_Exhaust_'+side,(0,-.74,0),nozzle)
    for i in range(8):
        angle=i*math.tau/8
        box('Nozzle cooling fin',(radius*.86*math.cos(angle),-.18,radius*.86*math.sin(angle)),(.1,.65,.1),'edge_steel',.02,nozzle)

def radiator(x,y,z,length=3.8):
    side='L' if x<0 else 'R'
    pivot=empty('Anim_Radiator_'+side,(x,y,z))
    cylinder('Radiator hinge',(0,0,0),.13,length,'edge_steel',parent=pivot)
    box('Radiator frame',(math.copysign(.56,x),0,0),(1.2,length,.16),'structural_dark',.04,pivot)
    for i in range(6):box('Radiator heat channel',(math.copysign(.56,x),(i-2.5)*length/6,.11),(1.01,.11,.08),'edge_steel',.015,pivot)

def survey_array(x,y,z,large=False):
    cylinder('Survey gimbal pedestal',(x,y,z),.38,.6,'edge_steel','Z')
    sensor=empty('Anim_Sensor',(x,y,z+.4))
    cylinder('Survey face backing',(0,0,.1),1.15 if large else .7,.22,'structural_dark','Z',sensor)
    cylinder('Recessed survey lens',(0,0,.24),.93 if large else .53,.08,'enamel_teal','Z',sensor)
    for s in (-1,1):box('Sensor guard',(s*(1.1 if large else .67),0,.2),(.12,1.1,.24),'enamel_cream',.03,sensor)

def common(name, engine_x, engine_y, engine_z, radius):
    for side in (-1,1):
        engine(side*engine_x,engine_y,engine_z,radius)
        for y in (-3.8,1.0):
            box('Landing pad recess',(side*1.6,y,-.9),(.85,1.35,.28),'structural_dark')
            box('Emergency release',(side*1.7,y,-1.08),(.28,.65,.08),'safety_orange',.025)
        box('Forward recognition lamp',(side*.85,6.1,.25),(.28,.12,.14),'enamel_teal',.03)
    box('Aft pressure bulkhead',(0,-6.35,.1),(2.7,.20,1.5),'edge_steel')
    box('Aft airlock',(0,-6.5,.1),(2.25,.10,1.25),'enamel_teal')
    for side in (-1,1):box('Airlock release',(side*.62,-6.6,.1),(.1,.08,.4),'safety_orange',.025)
    empty('Socket_Mission_propulsion',(0,-1.6,1.65))
    empty('Socket_Mission_utility',(4,.7,1.1))
    # Registry is confined to a quiet dorsal panel and does not substitute for form.
    bpy.ops.object.text_add(location=(0,-3.4,1.55));obj=bpy.context.object
    obj.data.body=name.upper();obj.data.align_x='CENTER';obj.data.size=.30;obj.data.extrude=.002
    obj.data.materials.append(ink.material('structural_dark'));bpy.ops.object.convert(target='MESH');obj.name='Hull registry'

def explorer(advanced=False):
    loft('Survey keel',[(-6.3,1.7,.82,0),(-4,2.3,1,0),(2,2.4,.9,0),(6.7,.7,.45,-.1)],'structural_dark')
    loft('Central armored spine',[(-5.8,1.9,.2,1),(-2,2.05,.22,1.16),(1.2,1.9,.17,1.1)])
    cockpit(5.5)
    for s in (-1,1):
        loft('Independent survey outrigger',[(-5.7,1.0,.7,.2),(-2,1.05,.65,.2),(4.5,.72,.45,.15),(7.5,.12,.18,.1)],'enamel_cream',s*3.1)
        box('Isolated optical rail',(s*3.15,2,.76),(.44,3.2,.12),'enamel_teal')
        wing('Open truss shoulder',[(s*1.7,-4),(s*5,-5.7),(s*5,-3.6),(s*2.1,-1.2)],.15,.55,'edge_steel')
        radiator(s*2.15,-2,1.18)
    survey_array(0,-4.1,1.6,advanced)
    if advanced:
        # Two open annular sensor arcs: a visible central aperture, not a filled disc.
        for s in (-1,1):
            wing('Deep survey crescent',[(s*2,1.8),(s*5.5,.2),(s*7.1,-3.4),(s*6.5,-6.0),(s*5.4,-2.0),(s*2.9,.6)],.6,.42)
            for y in (-4,-2):box('Interferometer tile',(s*6,y,.96),(.4,.9,.16),'enamel_teal')
        loft('Ventral long baseline scanner',[(-2,1.2,.25,-1.25),(2,1.15,.3,-1.25),(5,.42,.22,-.9)],'enamel_teal')
    common('orion' if advanced else 'aster',5.05,-5.05,.10,1.05)

def interceptor(advanced=False):
    loft('Long narrow pressure spine',[(-6.4,1.35,.8,0),(-3,1.9,1,0),(3.8,1.35,.65,0),(8.5,.12,.16,-.1)],'structural_dark')
    loft('Dorsal streamlining',[(-5.8,1.5,.24,1),(-1,1.62,.22,1.1),(5.9,.72,.18,.45),(8.3,.14,.08,.1)])
    for side in (-1,1):box('Flush dorsal armor insert',(side*.9,-3.5,1.28),(.46,2.4,.06),'enamel_teal',.025)
    cockpit(5.7,1.35,1.0)
    for s in (-1,1):
        outline=[(s*1.1,1.2),(s*6.3,-2.7),(s*7.0,-6.0),(s*3.1,-5.0),(s*1.1,-3.0)]
        if advanced:outline=[(s*1.2,-2),(s*6.7,3.7),(s*7.15,5.4),(s*7.3,-4.7),(s*3.7,-6),(s*1.3,-4.3)]
        wing('Forward sweep blade' if advanced else 'Swept acceleration wing',outline,.05,.38)
        wing('Recessed wing heat shield',[(s*2.7,-2.9),(s*5.1,-3.5),(s*5.9,-5.1),(s*3.6,-4.5)],.31,.10,'enamel_teal')
        fin=loft('Canted vertical stabilizer',[(-6.3,.13,1.0,1.3),(-4.8,.15,1.55,1.4),(-2,.10,.22,.65)],'enamel_teal',s*3.6)
        fin.rotation_euler.y=-s*.16
        radiator(s*1.65,-2.7,1.23,3)
    if advanced:
        for s in (-1,1):loft('Spinal lance acceleration rail',[(1.7,.25,.22,-.4),(7.1,.22,.18,-.38),(8,.13,.12,-.3)],'edge_steel',s*.53)
    common('spectre' if advanced else 'peregrine',4.65,-4.45,-.1,1.15 if advanced else 1.0)

def hauler(advanced=False):
    loft('Load bearing keel',[(-6.4,2.15,.9,0),(-4.8,2.65,1.1,0),(2.7,2.65,1,0),(6.6,1.45,.6,-.05)],'structural_dark')
    loft('Armored command deck',[(-5.5,2.2,.22,1.1),(0,2.25,.2,1.2),(2,1.9,.15,1.1)])
    cockpit(6.5,1.9,1.2)
    for s in (-1,1):
        box('Cargo load rail',(s*3.45,-1.3,-.5),(.55,9.7,.6),'edge_steel')
        for index,y in enumerate((-4.5,-1.5,1.5)):
            x=s*3.65
            box('Sealed cargo pressure module',(x,y,.30),(2.3,2.7,2.0),'enamel_teal',.18)
            box('Cargo inspection armor',(x+s*1.19,y,.30),(.11,2.25,1.55),'enamel_cream',.06)
            box('Container central latch',(x+s*1.28,y,.30),(.09,.35,.4),'safety_orange',.03)
            for yy in (-1.15,1.15):box('Cargo restraint frame',(x,y+yy,.32),(2.5,.17,2.15),'structural_dark',.05)
            if advanced:
                box('Upper sealed freight pod',(x,y,2.16),(2.15,2.64,1.5),'enamel_cream',.15)
                box('Upper restraint latch',(x+s*1.10,y,2.2),(.08,.4,.35),'safety_orange',.02)
                for yy in (-1.10,1.10):box('Upper cargo locking band',(x,y+yy,2.17),(2.25,.14,1.57),'edge_steel',.025)
                box('Upper cargo service panel',(x,y,2.96),(1.35,1.6,.055),'enamel_teal',.025)
        radiator(s*1.75,-2.8,1.4,3.7)
    if advanced:
        box('Freight gantry crossbeam',(0,-4.6,3.25),(9.65,.6,.6),'edge_steel')
        for s in (-1,1):box('Gantry upright',(s*4.85,-4.6,1.35),(.4,.65,3.8),'structural_dark')
        cylinder('Bastion field generator',(0,-4.0,1.8),1.0,.5,'enamel_teal','Z')
    else:survey_array(0,-4.5,1.5)
    common('atlas' if advanced else 'ox',5.7,-4.95,.10,1.05)

def lighting():
    world=bpy.data.worlds.new('Neutral inspection studio');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.10,.14,.18,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.5;bpy.context.scene.world=world
    for loc,power,size in [((8,10,16),2300,10),((-10,0,7),1700,9),((2,-13,9),2400,8)]:
        bpy.ops.object.light_add(type='AREA',location=loc);lamp=bpy.context.object
        lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size
        lamp.rotation_euler=(Vector((0,0,.4))-lamp.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(19,23,18));camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,.4))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=23;bpy.context.scene.camera=camera

def main():
    selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    rows=[]
    for name,builder,advanced in [('aster',explorer,False),('peregrine',interceptor,False),('ox',hauler,False),('orion',explorer,True),('spectre',interceptor,True),('atlas',hauler,True)]:
        if selected and name not in selected:continue
        bpy.ops.wm.read_factory_settings(use_empty=True);builder(advanced);lighting()
        scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=16
        scene.render.resolution_x=960;scene.render.resolution_y=800;scene.render.resolution_percentage=100
        scene.view_settings.view_transform='AgX'
        source=SOURCE/(name+'.blend');output=OUTPUT/(name+'.glb')
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        ink.consolidate_static_surfaces()
        bpy.ops.object.select_all(action='DESELECT')
        for obj in scene.objects:
            if obj.type in ('MESH','EMPTY'):obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True)
        scene.render.filepath=str(CAPTURE/(name+'.png'));bpy.ops.render.render(write_still=True)
        meshes=[o for o in scene.objects if o.type=='MESH'];triangles=0
        for obj in meshes:obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        row={'id':name,'tier':5 if advanced else 3,'source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),'triangles':triangles,'meshes':len(meshes),'style':'ink-v1','forward':'Blender +Y / Godot -Z','sockets':['Socket_Exhaust_L','Socket_Exhaust_R'],'motion':['Anim_Radiator_L','Anim_Radiator_R','Anim_Nozzle_L','Anim_Nozzle_R'],'review':'Blender rendered; game verification pending'}
        rows.append(row);print('ADVANCED_HULL_EXPORTED',name,triangles,flush=True)
    manifest=SOURCE/'manifest.json'
    existing=json.loads(manifest.read_text()) if manifest.exists() else []
    retained=[row for row in existing if row['id'] not in [item['id'] for item in rows]]
    manifest.write_text(json.dumps(retained+rows,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
