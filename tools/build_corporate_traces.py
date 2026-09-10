"""SP08: three purpose-built orbital trace instruments, Blender sources and INK exports."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
code=(ROOT/'tools/build_orbital_ports.py').read_text().split('\nrecords=[]')[0]
code=code.replace('(470,-610,410)','(105,-135,95)').replace('ortho_scale=570','ortho_scale=150').replace('tools/build_orbital_ports.py','tools/build_corporate_traces.py')
exec(compile(code,__file__,'exec'))
CAP=ROOT/'docs/production/media/corporate-traces';CAP.mkdir(parents=True,exist_ok=True)
def pivot(name,p):
    bpy.ops.object.empty_add(location=p);o=bpy.context.object;o.name=name;return o

def lotus():
    # Three curved petals protect an exposed navigational lantern. No enclosed base.
    cyl('Beacon battery drum',(0,0,-19),15,22,'enamel_cream')
    torus('Battery compression seal',(0,0,-27),15,1.5,'structural_dark')
    cyl('Lantern mast',(0,0,9),4,44)
    cyl('Lantern diffuser',(0,0,23),8,14,'enamel_teal')
    for i in range(3):
        a=i*math.tau/3
        points=[]
        for j in range(17):
            u=j/16;r=13+25*math.sin(u*math.pi*.9);z=-24+62*u
            points.append((r*math.cos(a),r*math.sin(a),z))
        curve=bpy.data.curves.new('Continuous petal rail','CURVE');curve.dimensions='3D';curve.resolution_u=5;curve.bevel_depth=2.6;curve.bevel_resolution=4;curve.use_fill_caps=True
        spline=curve.splines.new('BEZIER');spline.bezier_points.add(8)
        for bp,p in zip(spline.bezier_points,points[::2]):bp.co=p;bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
        rail=bpy.data.objects.new('Swept petal rail',curve);bpy.context.collection.objects.link(rail);rail.data.materials.append(ink.material('enamel_cream'))
        bpy.ops.object.select_all(action='DESELECT');rail.select_set(True);bpy.context.view_layer.objects.active=rail;bpy.ops.object.convert(target='MESH')
        for poly in rail.data.polygons:poly.use_smooth=True
        for z,r in [(-15,24),(0,34),(16,38)]:
            p=(r*math.cos(a),r*math.sin(a),z)
            o=box('Petal reflective vane',p,(16,2,10),'enamel_teal');o.rotation_euler.z=a+math.pi*.5
        beam('Petal base clevis',(0,0,-27),points[0],2,'edge_steel')
    head=pivot('Anim_Beacon',(0,0,33))
    torus('Rotating navigation halo',(0,0,0),12,1.7,'enamel_cream',head)
    for x in [-10,10]:
        o=box('Pulse emitter',(x,0,0),(4,6,4),'enamel_teal',head);o.data.materials.clear();o.data.materials.append(SIGNAL)
    box('Public beacon plaque',(0,-15.3,-18),(18,2,16),'structural_dark')
    marks.mount('Lotus pioneering mark','lotus',(0,-16.5,-18),(1,0,0),(0,0,1),13)
    for x in [-11,11]:beam('Station keeping thruster',(x,0,-29),(x,0,-35),3,'structural_dark')

def mine():
    # Open maintenance cradle, spare drill spindle and two locked mineral bins.
    box('Open worksite backbone',(0,0,-18),(80,33,8),'structural_dark')
    for x in [-35,35]:
        box('End frame',(x,0,-10),(5,39,13),'safety_orange')
        for y in [-15,15]:cyl('Anchor collar',(x,y,-18),4,13)
    for x in [-22,2]:
        cyl('Collection canister',(x,1,0),10,29,'enamel_cream')
        for z in [-12,13]:torus('Canister locking rim',(x,1,z),10,1.6,'safety_orange')
        cyl('Sealed lid',(x,1,15),9,3,'structural_dark')
        box('Bin inspection panel',(x,-9,1),(12,2,11),'enamel_teal')
    box('Maintenance bed',(27,0,-7),(18,33,11),'enamel_teal')
    for y in [-11,11]:box('Tool securing jaw',(27,y,1),(17,4,9),'edge_steel')
    beam('Removed drill spindle',(27,-9,5),(27,13,5),4,'structural_dark')
    for y in [-7,-2,3,8]:
        o=torus('Spindle service teeth',(27,y,5),5,1.6,'safety_orange');o.rotation_euler.x=math.pi*.5
    crane=pivot('Anim_ServiceArm',(-38,12,-8))
    beam('Crane upright',(0,0,0),(0,0,37),3,'edge_steel',crane)
    beam('Crane elbow',(0,0,37),(26,0,37),3,'enamel_cream',crane)
    beam('Hydraulic piston',(0,0,20),(18,0,36),1.5,'safety_orange',crane)
    beam('Raised empty gripper',(26,0,37),(26,0,26),2,'structural_dark',crane)
    for x in [22,30]:beam('Separated gripper fingers',(26,0,26),(x,0,20),1.7,'safety_orange',crane)
    box('Service identity plate',(0,-19,-14),(21,2,12),'structural_dark')
    marks.mount('mine collection mark','mine',(0,-20.2,-14),(1,0,0),(0,0,1),16)

def coopertech():
    # Armored sealed test cassette and independent watch head, no eye/pyramid motif.
    box('Sealed cassette chassis',(0,0,-3),(52,36,42),'structural_dark')
    for x in [-24,24]:
        o=box('Sloped armored shoulder',(x,0,9),(16,41,34),'edge_steel');o.rotation_euler.y=(-1 if x>0 else 1)*.22
        box('Armored lower runner',(x,0,-28),(12,48,9),'structural_dark')
    for z in [-16,17]:box('Front armor lip',(0,-20,z),(45,6,7),'edge_steel')
    box('Sealed hatch',(0,-20,-1),(34,4,27),'enamel_cream')
    for x in [-13,13]:box('Mechanical seal bar',(x,-24,0),(5,5,28),'safety_orange')
    box('Identity recessed plaque',(0,-24,1),(17,2,18),'structural_dark')
    marks.mount('Combat robotics seal','coopertech',(0,-25.2,1),(1,0,0),(0,0,1),13)
    for y in [-10,0,10]:box('Heat exchange fins',(0,y,20),(33,3,5),'structural_dark')
    cyl('Watcher bearing',(0,9,26),8,8)
    head=pivot('Anim_WatchHead',(0,9,34))
    box('Broad armored watch visor',(0,0,0),(30,17,13),'edge_steel',head)
    box('Recessed sensor slit',(0,-9,0),(23,2,4),'structural_dark',head)
    for x in [-8,8]:
        o=box('Paired rangefinder',(x,-10,0),(4,1,2),'enamel_teal',head);o.data.materials.clear();o.data.materials.append(SIGNAL)
    for x in [-32,32]:beam('Directional aerial',(x,13,5),(x,13,35),1.3,'structural_dark')

records=[]
for company,build in [('lotus',lotus),('mine',mine),('coopertech',coopertech)]:
    bpy.ops.wm.read_factory_settings(use_empty=True);SIGNAL=signal_material();build();records.append(export('trace_'+company))
(SOURCE/'corporate_traces.json').write_text(json.dumps(records,indent=2)+'\n')
