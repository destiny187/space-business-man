"""SP09: damaged CARRIER pod, recovery cradle and receiving dock; original Blender assets."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
code=(ROOT/'tools/build_orbital_ports.py').read_text().split('\nrecords=[]')[0]
code=code.replace('(470,-610,410)','(62,-84,65)').replace('ortho_scale=570','ortho_scale=100').replace('tools/build_orbital_ports.py','tools/build_freight_salvage.py')
code=code.replace("cam.data.ortho_scale=100;scene.camera=cam", "cam.data.ortho_scale=100;scene.camera=cam\n    if id=='freight_receiver':\n        center=Vector((0,36,-5));cam.location=Vector((90,-100,85))+center;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=145")
exec(compile(code,__file__,'exec'))
CAP=ROOT/'docs/production/media/freight-salvage';CAP.mkdir(parents=True,exist_ok=True)
def pivot(name,p):
    bpy.ops.object.empty_add(location=p);o=bpy.context.object;o.name=name;return o

def pod():
    box('Pressure vessel',(0,0,0),(20,22,16))
    for y in [-8,8]:box('Load bearing collar',(0,y,0),(21,2.3,17),'edge_steel')
    box('Blue freight band',(0,0,8.1),(17,13,1.3),'enamel_teal')
    box('Recessed loading door',(0,-11.3,0),(14,.8,11),'structural_dark')
    for x in [-6,6]:box('Handling latch',(x,-11.9,0),(1.8,1.5,7),'safety_orange')
    marks.mount('Space Y cargo seal','space_y',(0,-12.45,0),(1,0,0),(0,0,1),8)
    marks.mount('Space Y dorsal seal','space_y',(0,0,8.85),(1,0,0),(0,1,0),9)
    for x in [-10,10]:
        beam('Recovered pod side rail',(x,-8,0),(x,8,0),.9)
        for y in [-7,7]:beam('Lift eye riser',(x,y,7),(x,y,11),.8,'safety_orange')
    # A broken attachment bracket, not a cracked pressure vessel leaking loot.
    beam('Broken attachment stump',(-10,4,3),(-14,4,6),1.2,'edge_steel')
    beam('Bent clamp arm',(-14,4,6),(-16,5,3),1.2,'edge_steel')
    box('Hazard beacon housing',(8,0,10),(4,6,3),'structural_dark')
    light_bar('SOS indicator',(8,-1,11.8),(2,3,1))

def cradle(receiving=False):
    box('Recovery spine',(0,0,-11),(28,30,4),'structural_dark')
    for x in [-13,13]:
        box('Pod guide runner',(x,0,-7),(3,28,7),'edge_steel')
        for y in [-10,10]:
            hinge=pivot('Anim_Clamp_%s_%s'%(x,y),(x,y,-5))
            beam('Articulated retaining jaw',(0,0,0),(-math.copysign(1,x),0,8),1.5,'safety_orange',hinge)
            box('Soft contact pad',(-math.copysign(1,x),0,8),(3,4,3),'structural_dark',hinge)
    cyl('Recovery winch',(0,9,-17),4,7,'enamel_teal')
    if receiving:
        # A deck extension reaches back to the existing port, clear of NPC berths.
        for x in [-12,12]:beam('Receiving dock bridge',(x,12,-12),(x,95,-12),3,'edge_steel')
        box('Port connection saddle',(0,93,-12),(38,8,12),'structural_dark')
        box('Receiver plate',(0,-16,-8),(17,2,12),'enamel_cream')
        marks.mount('Return destination','space_y',(0,-17.2,-8),(1,0,0),(0,0,1),10)
        for x in [-14,14]:light_bar('Handover guide',(x,-10,-2),(2,7,2))
    else:
        for x in [-16,16]:beam('Vessel mounting arm',(x,0,-11),(x,0,21),2,'edge_steel')
        box('Vessel mount',(0,0,23),(36,16,4),'enamel_cream')
records=[]
for id,build in [('lost_freight_pod',pod),('freight_cradle',lambda:cradle(False)),('freight_receiver',lambda:cradle(True))]:
    bpy.ops.wm.read_factory_settings(use_empty=True);SIGNAL=signal_material();build();records.append(export(id))
(SOURCE/'freight_salvage.json').write_text(json.dumps(records,indent=2)+'\n')
