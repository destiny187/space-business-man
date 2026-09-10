"""SP10 authored orbital drill worksite and replacement drive cartridge."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
code=(ROOT/'tools/build_orbital_ports.py').read_text().split('\nrecords=[]')[0]
code=code.replace('(470,-610,410)','(62,-84,65)').replace('ortho_scale=570','ortho_scale=95').replace('tools/build_orbital_ports.py','tools/build_mine_maintenance.py')
code=code.replace("cam.data.ortho_scale=95;scene.camera=cam", "cam.data.ortho_scale=95;scene.camera=cam\n    if id=='mine_repair_worksite':\n        center=Vector((-35,0,-5));cam.location=Vector((190,-235,180))+center;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=290")
exec(compile(code,__file__,'exec'))
CAP=ROOT/'docs/production/media/mine-maintenance';CAP.mkdir(parents=True,exist_ok=True)
def pivot(name,p):
    bpy.ops.object.empty_add(location=p);o=bpy.context.object;o.name=name;return o

def cartridge():
    box('Cartridge foot',(0,0,-7),(20,22,3),'structural_dark')
    for x in [-8,8]:
        box('Protected lifting rib',(x,0,0),(3,23,17),'safety_orange')
        for y in [-9,9]:beam('Corner post',(x,y,-7),(x,y,9),1.1,'edge_steel')
    for x in [-4,4]:
        cyl('Drive pressure cell',(x,0,0),4,13,'enamel_cream')
        torus('Cell coupling',(x,0,5),4,.75,'edge_steel')
    box('Central power bus',(0,0,6),(3,20,3),'enamel_teal')
    for y in [-8,8]:box('Insulated connector',(0,y,7.5),(4,3,2),'structural_dark')
    box('Cartridge service cover',(0,-10.5,0),(14,3,12),'enamel_cream')
    marks.mount('mine repair identity','mine',(0,-12.2,0),(1,0,0),(0,0,1),10)

def seat():
    box('Replacement cartridge socket',(0,0,-11),(28,30,5),'structural_dark')
    for x in [-13,13]:
        box('Cartridge guide rail',(x,0,-4),(3,30,10),'edge_steel')
        for y in [-10,10]:
            arm=pivot('Anim_Clamp_%d_%d'%(x,y),(x,y,-3))
            beam('Locking jaw',(0,0,0),(-math.copysign(1,x),0,7),1.5,'safety_orange',arm)
            box('Locking pad',(-math.copysign(1,x),0,7),(3,4,3),'structural_dark',arm)

def supply():
    seat();box('Supply rack spine',(0,0,-19),(40,34,9),'enamel_cream')
    for x in [-18,18]:beam('Supply station retaining stanchion',(x,9,-21),(x,19,13),2,'edge_steel')
    box('Supply registry',(0,19,14),(25,4,9),'structural_dark')
    marks.mount('Replacement stock mark','mine',(0,16.8,14),(1,0,0),(0,0,1),7)

def worksite():
    seat()
    # A captured asteroid is held between actual opposing anchors, beside a linear drill.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1,location=(-105,0,-9));rock=bpy.context.object;rock.name='Captured ore-bearing asteroid';rock.scale=(40,29,34);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);rock.data.materials.append(ink.material('structural_dark'))
    for y in [-24,24]:
        beam('Anchoring truss',(-129,y,-23),(48,y,-23),4,'edge_steel')
        beam('Asteroid clamp',(-128,y,-23),(-129,y,13),3,'safety_orange')
        box('Counterweight foot',(-125,y,-26),(24,17,8),'structural_dark')
    box('Drill machine bed',(-48,0,-15),(40,35,9),'enamel_teal')
    for y in [-12,12]:beam('Drill translation rail',(-63,y,-8),(-25,y,-8),2.3,'edge_steel')
    slide=pivot('Anim_DrillSlide',(-42,0,4))
    box('Sealed drive head',(0,0,0),(22,26,24),'enamel_cream',slide)
    rotor=pivot('Anim_DrillRotor',(-54,0,4));rotor.parent=slide;rotor.location=(-12,0,0)
    beam('Drill spindle',(0,0,0),(-20,0,0),5,'edge_steel',rotor)
    for x in [-7,-13,-19]:
        o=torus('Helical cutter collar',(x,0,0),7,1.5,'safety_orange',rotor);o.rotation_euler.y=math.pi*.5
    for y in [-9,9]:beam('Power conduit',(-43,y,-8),(-15,y,-10),1.7,'structural_dark')
    box('Ore collection bin',(39,0,-7),(31,31,24),'enamel_cream')
    for y in [-13,13]:box('Collection bin rail',(39,y,6),(34,4,5),'safety_orange')
    belt=pivot('Anim_OreTray',(35,0,9))
    for x,y,z in [(0,0,0),(-5,6,1),(7,-5,0)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=4,location=(x,y,z));o=bpy.context.object;o.name='Processed ore on shaker tray';o.parent=belt;o.data.materials.append(ink.material('edge_steel'))
    repair=pivot('Anim_RepairArm',(14,16,-7))
    beam('Service actuator upright',(0,0,0),(0,0,35),2.5,'edge_steel',repair)
    beam('Service actuator reach',(0,0,35),(-13,-8,35),2.2,'enamel_cream',repair)
    beam('Diagnostic probe',(-13,-8,35),(-13,-8,21),1.5,'safety_orange',repair)
    box('Worksite front plaque',(-29,-22,-15),(31,4,14),'structural_dark')
    marks.mount('mine industrial operator','mine',(-29,-24.2,-15),(1,0,0),(0,0,1),22)
    for x in [-44,-18]:
        lamp=pivot('Anim_StatusLamp_'+str(x),(x,-20,9));o=box('Replaceable fault indicator',(0,0,0),(4,3,7),'enamel_teal',lamp);o.data.materials.clear();o.data.materials.append(SIGNAL)
records=[]
for id,build in [('mine_service_pack',cartridge),('mine_supply_rack',supply),('mine_repair_worksite',worksite)]:
    bpy.ops.wm.read_factory_settings(use_empty=True);SIGNAL=signal_material();build();records.append(export(id))
(SOURCE/'mine_maintenance.json').write_text(json.dumps(records,indent=2)+'\n')
