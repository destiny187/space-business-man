"""Replace priority legacy industry models; preserve game IDs, scale and motion axes.

Blender --background --python tools/build_ink_industry.py -- [asset IDs]
Editable sources precede export consolidation. Review cameras never enter game GLBs.
"""
from pathlib import Path
import json
import math
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as ink

KINDS = ['miner', 'atmosphere', 'thermal', 'water', 'biolab']
SOURCE = ROOT / 'art/blender'
GAME = ROOT / '우주-비즈니스/assets/models'
REVIEW = ROOT / 'docs/production/media/ink-industry'
REVIEW.mkdir(parents=True, exist_ok=True)
P = {}


def finish(obj, name, role, bevel=.025, parent=None):
    obj.name = name
    obj.data.materials.append(P[role])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ink.manufactured_edges(obj, bevel)
    if parent:
        world = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_world = world
    return obj


def box(name, loc, size, role, bevel=.035, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    return finish(obj, name, role, bevel, parent)


def cyl(name, loc, radius, depth, role, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth,
                                      location=loc, rotation=rot)
    return finish(bpy.context.object, name, role, min(.025, depth*.15), parent)


def ring(name, loc, radius, tube, role, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=10,
                                   major_radius=radius, minor_radius=tube,
                                   location=loc, rotation=rot)
    return finish(bpy.context.object, name, role, 0, parent)


def rod(name, a, b, radius, role, parent=None):
    a, b = Vector(a), Vector(b)
    obj = cyl(name, (a+b)*.5, radius, (a-b).length, role)
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    bpy.context.view_layer.update()
    if parent:
        world = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_world = world
    return obj


def pipe(name, points, radius, role):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = point.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, name, role, 0)


def pivot(name, loc, rot=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    bpy.context.view_layer.update()
    return obj


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    P.clear()
    for short, role in {'cream':'enamel_cream', 'teal':'enamel_teal',
                        'orange':'safety_orange', 'dark':'structural_dark',
                        'steel':'edge_steel', 'rubber':'rubber'}.items():
        P[short] = ink.material(role)
    for role, color in {'status':(.22,.85,.64), 'culture':(.24,.54,.21),
                        'water':(.13,.42,.61)}.items():
        mat = bpy.data.materials.new('Process '+role)
        mat.use_nodes = True
        mat.diffuse_color = (*color, 1)
        bsdf = mat.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = mat.diffuse_color
        bsdf.inputs['Roughness'].default_value = .4
        if role == 'status':
            bsdf.inputs['Emission Color'].default_value = mat.diffuse_color
            bsdf.inputs['Emission Strength'].default_value = .35
        P[role] = mat
    glass=bpy.data.materials.new('Culture observation glass')
    glass.use_nodes=True
    glass.diffuse_color=(.17,.54,.45,.20)
    glass.surface_render_method='DITHERED'
    glass.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=glass.diffuse_color
    glass.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.20
    glass.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.22
    P['glass']=glass


def miner():
    # Original -Y forward, 2.2m wheelbase/body envelope, original drill endpoint.
    box('Cast suspension chassis', (0,0,.57), (1.55,2.2,.34), 'dark', .12)
    box('Rounded equipment shell', (0,-.12,1.04), (1.46,1.42,.70), 'teal', .16)
    box('Upper lid seal', (0,-.12,1.40), (1.43,1.40,.09), 'dark', .045)
    box('Ceramic upper armour', (0,-.12,1.48), (1.46,1.43,.13), 'cream', .065)
    for x in [-.88,.88]:
        side = -1 if x < 0 else 1
        for y in [-.74,0,.74]:
            rod('Suspension swing arm', (x*.70,y+.17,.69), (x,y,.46), .065, 'steel')
            rod('Damper housing', (x*.72,y+.24,.83), (x*.93,y+.05,.52), .047, 'dark')
            wheel = pivot('Anim_Wheel_%s_%s' % (x,y), (x*1.19,y,.46), (0,math.pi/2,0))
            ring('Rounded rubber tyre', (x,y,.46), .285,.105,'rubber',(0,math.pi/2,0),wheel)
            cyl('Wheel barrel', (x,y,.46), .28,.26,'dark',(0,math.pi/2,0),wheel)
            cyl('Enamel wheel rim',(x+side*.155,y,.46),.235,.05,'cream',(0,math.pi/2,0),wheel)
            cyl('Recessed wheel hub',(x+side*.186,y,.46),.15,.018,'dark',(0,math.pi/2,0),wheel)
            cyl('Axle cap',(x+side*.202,y,.46),.073,.045,'orange',(0,math.pi/2,0),wheel)
            for k in range(12):
                a = k*math.tau/12
                tread = box('Rubber traction pad',(x,y+math.sin(a)*.378,.46+math.cos(a)*.378),
                            (.24,.085,.038),'rubber',.012,wheel)
                # Preserve world pose under the axle pivot.
                matrix = tread.matrix_world.copy()
                from mathutils import Matrix
                matrix = Matrix.Translation(matrix.translation) @ Matrix.Rotation(-a,4,'X')
                tread.matrix_world = matrix
        box('Protective wheel arch',(x,0,.90),(.37,2.17,.16),'cream',.07)
        box('Side service recess',(x*.84,.18,1.12),(.055,.68,.31),'dark',.025)
        for y in [-.02,.16,.34]:
            box('Cooling louvre',(x*.89,y,1.12),(.045,.065,.22),'steel',.015)
    # The sensor head has real bezels, protected lenses and a neck joint.
    cyl('Sensor neck',(0,-.41,1.60),.18,.22,'dark')
    box('Sensor head',(0,-.46,1.80),(.83,.54,.37),'cream',.14)
    box('Recessed visor',(0,-.738,1.79),(.68,.055,.23),'dark',.085)
    for x in [-.20,.20]:
        ring('Optical lens bezel',(x,-.779,1.81),.075,.017,'steel',(math.pi/2,0,0))
        cyl('Survey optic',(x,-.788,1.81),.058,.018,'status',(math.pi/2,0,0))
    box('Cargo bed',(0,.91,.95),(1.26,.62,.45),'dark',.08)
    for x in [-.57,.57]:box('Cargo side wall',(x,.91,1.20),(.12,.65,.35),'teal',.045)
    box('Cargo tailgate',(0,1.20,1.16),(1.20,.12,.32),'cream',.04)
    for x in [-.37,.37]:box('Cargo latch',(x,1.275,1.18),(.12,.055,.16),'orange',.025)
    rod('Antenna',( .56,.32,1.53),(.56,.32,2.29),.024,'steel')
    cyl('Antenna beacon',(.56,.32,2.34),.067,.10,'status')
    # Fixed load-bearing knuckles and hydraulic feed; only the bit spins.
    for loc in [(-.43,-.16,1.58),(-.43,-1.05,1.69)]:
        cyl('Arm knuckle',loc,.15,.27,'dark',(0,math.pi/2,0))
        cyl('Knuckle end cap',(loc[0]-.15,loc[1],loc[2]),.094,.055,'orange',(0,math.pi/2,0))
    rod('Arm casting',(-.43,-.16,1.58),(-.43,-1.05,1.69),.105,'cream')
    rod('Drill feed housing',(-.43,-1.05,1.69),(-.43,-1.69,1.35),.115,'teal')
    rod('Polished feed piston',(-.43,-1.52,1.43),(-.43,-1.82,1.35),.076,'steel')
    pipe('Hydraulic hose',[(-.54,-.13,1.55),(-.66,-.61,1.83),(-.63,-1.12,1.90),(-.54,-1.67,1.47)],.032,'rubber')
    cyl('Drill protective collar',(-.43,-1.77,1.35),.215,.26,'orange',(math.pi/2,0,0))
    rotor = pivot('ToolRotor',(-.43,-2.12,1.35),(math.pi/2,0,0))
    bpy.ops.mesh.primitive_cone_add(vertices=40,radius1=.225,radius2=.025,depth=.65,
                                    location=(-.43,-2.12,1.35),rotation=(math.pi/2,0,0))
    finish(bpy.context.object,'Tapered drill core','steel',.012,rotor)
    for k in range(3):
        a=k*math.tau/3
        # Broad carbide teeth describe rotation even under a flat toon band.
        rod('Carbide flute',(-.43+math.cos(a)*.19,-1.83,1.35+math.sin(a)*.19),
            (-.43+math.cos(a+.5)*.052,-2.39,1.35+math.sin(a+.5)*.052),.032,'dark',rotor)


def foundation():
    box('Load bearing plinth',(0,0,.13),(3.6,3.6,.26),'dark',.09)
    box('Inset service apron',(0,0,.29),(3.42,3.42,.12),'steel',.035)
    for x in [-1.58,1.58]:
        for y in [-1.58,1.58]:cyl('Foundation anchor',(x,y,.37),.095,.08,'orange')


def terminal(x, y, z):
    box('Console support',(x,y+.08,(.35+z-.29)*.5),(.36,.26,z-.29-.35),'steel',.025)
    box('Service console seal',(x,y,z),(1.07,.40,.73),'dark',.10)
    box('Enamel service console',(x,y-.055,z),(1.0,.40,.66),'cream',.085)
    box('Recessed instrument face',(x-.12,y-.265,z+.07),(.54,.027,.28),'dark',.04)
    for xx in [-.25,-.08]:box('Process gauge',(x+xx,y-.288,z+.07),(.09,.02,.18),'status',.012)
    cyl('Emergency hand control',(x+.30,y-.295,z-.07),.078,.08,'orange',(math.pi/2,0,0))


def vessel(name, loc, radius, height, role):
    x,y,z=loc
    cyl(name+' shell',loc,radius,height,role)
    for zz in [z-height*.43,z+height*.43]:
        ring(name+' flange',(x,y,zz),radius,.045,'steel')
    for zz in [z-height*.5,z+height*.5]:cyl(name+' end cap',(x,y,zz),radius*.93,.14,'cream')


def fan():
    loc=(1.18,0,2.12)
    box('Fan pedestal',(1.18,0,1.16),(.69,.87,1.62),'teal',.13)
    ring('Fan intake rim',(1.18,0,2.14),.49,.075,'cream')
    cyl('Intake well',(1.18,0,2.02),.46,.05,'dark')
    rotor=pivot('Anim_Fan_Process',loc)
    cyl('Fan motor hub',loc,.12,.16,'orange',parent=rotor)
    for k in range(4):
        a=k*math.tau/4
        o=box('Swept fan blade',(1.18+math.cos(a)*.24,math.sin(a)*.24,2.12),
              (.38,.15,.045),'steel',.025,rotor)
        o.rotation_euler.z=a+.28
    for y in [-.47,.47]:rod('Intake guard',( .65,y,2.25),(1.71,y,2.25),.028,'dark')


def atmosphere():
    foundation()
    vessel('Air separation column',(-.45,.13,1.87),.70,2.95,'cream')
    for z in [1.0,1.7,2.4]:
        box('Filter cassette',(-.45,-.60,z),(.87,.27,.49),'teal',.08)
        box('Cassette latch',(-.10,-.755,z),(.075,.05,.18),'orange',.015)
    cyl('Exhaust neck',(-.45,.13,3.52),.37,.34,'dark')
    cyl('Weather hood',(-.45,.13,3.78),.60,.17,'cream')
    for x in [-.84,-.06]:rod('Hood support',(x,.13,3.42),(x,.13,3.76),.035,'steel')
    fan()
    pipe('Air transfer duct',[(1.18,.34,1.76),(.94,.77,1.9),(-.05,.66,2.43)],.14,'steel')
    terminal(-.22,-1.09,.91)


def thermal():
    foundation()
    # A broad radiator bank differentiates heat exchange from a pressure column.
    box('Heat exchanger spine',(-.43,.20,1.93),(1.42,.91,2.94),'dark',.10)
    for z in [.51,3.34]:box('Radiator header',(-.43,.20,z),(1.61,1.11,.20),'cream',.09)
    for x in [-1.12,.27]:box('Radiator side armour',(x,.20,1.92),(.18,1.05,2.77),'cream',.065)
    for z in [.86,1.28,1.70,2.12,2.54,2.96]:
        box('Heat exchange fin',(-.43,.13,z),(1.18,1.14,.11),'steel',.025)
        box('Fin leading shield',(-.43,-.47,z),(1.03,.08,.08),'orange',.02)
    for x in [-.80,-.08]:
        pipe('Heat circulation tube',[(x,.81,.62),(x,.84,1.65),(x,.84,3.21)],.095,'teal')
    fan()
    pipe('Coolant return',[(1.18,.39,.79),(.86,.86,.62),(.18,.81,.68)],.12,'steel')
    terminal(-.35,-1.02,.99)


def water():
    foundation()
    vessel('Water receiver',(-.43,.37,1.66),.74,2.45,'teal')
    vessel('Filter cartridge',(-1.24,-.52,1.15),.28,1.36,'cream')
    box('Receiver inspection recess',(-.43,-.385,1.72),(.32,.06,1.35),'dark',.08)
    box('Water level window',(-.43,-.428,1.66),(.20,.03,1.10),'water',.045)
    for z in [1.22,1.61,2.0]:box('Level graduation',(-.18,-.425,z),(.12,.04,.045),'cream',.01)
    cyl('Pump base',(1.18,0,.70),.34,.60,'dark')
    cyl('Pump guide',(1.18,0,1.25),.23,.76,'cream')
    pump=pivot('Anim_Piston_Process',(1.18,0,1.55))
    cyl('Polished pump piston',(1.18,0,1.55),.11,.72,'steel',parent=pump)
    cyl('Pump crosshead',(1.18,0,1.89),.30,.16,'orange',parent=pump)
    for y in [-.35,.35]:rod('Pump guide rail',(1.18,y,.76),(1.18,y,2.20),.045,'steel')
    box('Pump top tie',(1.18,0,2.23),(.36,.87,.14),'teal',.05)
    pipe('Pressure delivery',[(1.18,.17,.81),(1.00,.83,.78),(-.04,1.09,1.21)],.10,'steel')
    pipe('Filter outlet',[(-1.24,-.52,1.90),(-1.12,-.53,2.14),(-.76,-.02,2.2)],.07,'steel')
    terminal(.0,-1.13,.90)


def biolab():
    foundation()
    cyl('Culture base',(0,0,.61),1.11,.53,'dark')
    cyl('Culture lower shell',(0,0,1.18),1.06,.74,'teal')
    cyl('Culture chamber',(0,0,2.13),.90,1.34,'glass')
    cyl('Culture tray',(0,0,1.62),.76,.13,'dark')
    for i in range(3):
        a=i*math.tau/3
        x,y=math.cos(a)*.37,math.sin(a)*.37
        rod('Culture stem',(x,y,1.67),(x,y,2.51-i*.11),.045,'culture')
        for side in [-1,1]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,
                                                location=(x+side*.15,y,2.09+i*.08))
            leaf=bpy.context.object;leaf.scale=(.23,.11,.105);leaf.rotation_euler.y=-side*.55
            finish(leaf,'Cultured leaf','culture',0)
    for z in [1.49,2.81]:ring('Chamber seal',(0,0,z),.94,.065,'dark')
    for k in range(4):
        a=math.pi*.25+k*math.pi/2
        x,y=math.cos(a)*.94,math.sin(a)*.94
        box('Chamber protective upright',(x,y,2.15),(.16,.16,1.47),'cream',.045)
    cyl('Ceramic chamber roof',(0,0,2.90),1.04,.18,'cream')
    agitator=pivot('Anim_Agitator_Process',(0,0,3.12))
    ring('External culture drive',(0,0,3.12),.86,.05,'steel',parent=agitator)
    cyl('Agitator hub',(0,0,3.12),.16,.20,'orange',parent=agitator)
    for k in range(4):
        a=k*math.pi/2
        rod('Agitator spoke',(0,0,3.12),(.86*math.cos(a),.86*math.sin(a),3.12),.045,'dark',agitator)
        box('Culture paddle',(.86*math.cos(a),.86*math.sin(a),3.12),(.20,.20,.30),'teal',.045,agitator)
    for x in [-1.32,1.32]:
        vessel('Nutrient cartridge',(x,.25,1.06),.23,1.12,'cream')
        pipe('Culture feed',[(x,.25,1.63),(x,.31,1.86),(x*.63,.28,1.94)],.055,'steel')
    terminal(0,-1.13,1.02)


def render(kind):
    scene=bpy.context.scene
    scene.world=bpy.data.worlds.new('Temporary industry review')
    scene.world.color=(.16,.16,.16)
    box('Review floor',(0,0,-.065),(200,200,.10),'cream',0)
    center=Vector((0,0,1.15 if kind=='miner' else 1.9))
    bpy.ops.object.camera_add(location=(6,-8,5.5 if kind=='miner' else 6))
    cam=bpy.context.object
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=4.9 if kind=='miner' else 6.1
    scene.camera=cam
    for pos,energy in [((3,-5,7),1500),((-4,-1,5),850)]:
        bpy.ops.object.light_add(type='AREA',location=pos)
        light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=5
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.filepath=str(REVIEW/(kind+'-blender.png'))
    bpy.ops.render.render(write_still=True)


def main():
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else KINDS
    if not requested:requested=KINDS
    if set(requested)-set(KINDS):raise SystemExit('Unknown industry asset')
    records=json.loads((SOURCE/'manifest.json').read_text())
    for kind in requested:
        reset()
        globals()[kind]()
        bpy.context.scene.unit_settings.system='METRIC'
        bpy.context.view_layer.update()
        source=SOURCE/(kind+'.blend')
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        editable=sum(o.type=='MESH' for o in bpy.context.scene.objects)
        pivots={o.name:list(sum((list(r) for r in o.matrix_world),[])) for o in bpy.context.scene.objects
                if o.type=='EMPTY'}
        exported=ink.consolidate_static_surfaces()
        bpy.context.view_layer.update()
        for name,matrix in pivots.items():
            after=list(sum((list(r) for r in bpy.data.objects[name].matrix_world),[]))
            assert max(abs(a-b) for a,b in zip(matrix,after))<1e-6, name
        bpy.ops.export_scene.gltf(filepath=str(GAME/(kind+'.glb')),export_format='GLB',
                                  export_apply=True,export_cameras=False,export_lights=False)
        triangles=0
        for obj in bpy.context.scene.objects:
            if obj.type=='MESH':
                obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        for row in records:
            if row['id']==kind:
                row.update(generator='tools/build_ink_industry.py',material_preset=ink.PRESET['version'],
                           geometry='ink-family-remodeled',editable_objects=editable,export_objects=exported,
                           triangles=triangles,motion_pivots=pivots,blender=bpy.app.version_string)
        (SOURCE/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
        if kind != 'miner':
            motion_path=SOURCE/'ground-motion-manifest.json'
            motion=json.loads(motion_path.read_text())
            for row in motion['models']:
                if row['kind']==kind:
                    row.update(generator='tools/build_ink_industry.py',moving_node=next(iter(pivots)),
                               review=str((REVIEW/(kind+'-blender.png')).relative_to(ROOT)))
            motion_path.write_text(json.dumps(motion,ensure_ascii=False,indent=2)+'\n')
        render(kind)
        print('INK_INDUSTRY_EXPORTED',kind,editable,exported,triangles,flush=True)


if __name__ == "__main__":
    main()
