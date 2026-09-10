"""SP07: functional silhouettes for Lotus, mine, CooperTech and abandoned logistics.
Only the carrier berth sockets share a contract. Each building has its own structure.
"""
import bpy,sys,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
code=(ROOT/'tools/build_orbital_ports.py').read_text().split('\nrecords=[]')[0]
exec(compile(code,'tools/build_orbital_ports.py','exec'))

def pivot(name,p):
    bpy.ops.object.empty_add(location=p);o=bpy.context.object;o.name=name;return o

def arch(name,y,width,height,length):
    # Open barrel roof: a real hollow hangar, visible internal ribs and pressure doors.
    vertices=[];faces=[];steps=24
    for yy in [y-length*.5,y+length*.5]:
        for inner in [False,True]:
            for i in range(steps+1):
                a=math.pi*i/steps
                vertices.append((math.cos(a)*(width*.5-(4 if inner else 0)),yy,math.sin(a)*(height-(4 if inner else 0))-5))
    n=steps+1
    for i in range(steps):
        faces.extend([(i,i+1,2*n+i+1,2*n+i),(n+i,3*n+i,3*n+i+1,n+i+1),(i,n+i,n+i+1,i+1),(2*n+i,2*n+i+1,3*n+i+1,3*n+i)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,'enamel_cream',.7)
    for yy in [y-length*.5-1,y,y+length*.5+1]:
        for i in range(12):
            a=math.pi*i/12;b=math.pi*(i+1)/12
            beam('Hangar pressure ribs',(math.cos(a)*(width*.5+1),yy,math.sin(a)*height-5),(math.cos(b)*(width*.5+1),yy,math.sin(b)*height-5),2.1,'enamel_teal')

def photovoltaic(x,y,z,width,length):
    box('Radiator frame',(x,y,z),(width,length,4),'edge_steel')
    box('Dark thermal cells',(x,y,z+3),(width-5,length-5,1),'structural_dark')
    for yy in range(1,5):box('Radiator rails',(x,y-length*.5+length*yy/5,z+4),(width-5,1,1),'enamel_teal')

def landing_deck(side,kind):
    x=side*151;y=-38
    if kind=='lotus':
        box('Support craft launch wing',(x,y,-25),(84,137,9),'enamel_teal')
        box('Flush launch landing pad',(x,y,-19),(62,127,3),'edge_steel')
        for xx in [-38,38]:
            o=box('Flared launch shield',(x+xx,y,-12),(7,128,17));o.rotation_euler.y=xx/170
        for yy in [-49,27]:box('Launch chevrons',(x,y+yy,-16),(31,4,1))
    elif kind=='mine':
        # Sparse exposed structural gantry, unlike a sealed port passenger platform.
        for xx in [-36,36]:
            box('Heavy dock rail',(x+xx,y,-26),(9,153,16),'structural_dark')
            for yy in [-61,0,61]:box('Industrial mooring shoes',(x+xx,y+yy,-13),(12,15,10),'safety_orange')
        for yy in range(-60,65,20):box('Open steel grate',(x,y+yy,-22),(76,6,8),'edge_steel')
    else:
        box('Armored receiving slab',(x,y,-24),(78,145,15),'structural_dark')
        for xx in [-34,34]:
            o=box('Blast wall',(x+xx,y,-8),(10,140,27),'edge_steel');o.rotation_euler.y=xx/150
        for yy in [-56,0,56]:box('Recessed secure moorings',(x,y+yy,-15),(32,3,2),'safety_orange')
    for xx in [-29,29]:light_bar('Berth alignment lights',(x+xx,y,-13),(1.5,119,1.5))
    p=pivot('Anim_Crane_'+str(side),(x+side*49,y+22,-17))
    cyl('Cargo swivel shoe',(0,0,5),12,10,'edge_steel',p)
    if kind=='mine':
        for xx in [-6,6]:beam('Twin hydraulic columns',(xx,0,8),(xx,0,64),3,'safety_orange',p)
        box('Gantry drive head',(0,0,62),(18,17,12),'structural_dark',p)
    else:
        beam('Retractable cargo mast',(0,0,10),(0,0,58),5,'enamel_teal' if kind=='lotus' else 'edge_steel',p)
        cyl('Cargo elbow',(0,0,58),9,11,'edge_steel',p)
    beam('Transfer arm',(0,0,63),(-side*44,0,63),4,'enamel_cream' if kind=='lotus' else 'structural_dark',p)
    beam('Magnetic lifting wrist',(-side*44,0,63),(-side*44,0,37),2.5,'edge_steel',p)
    box('Transfer grapple',(-side*44,0,34),(17,12,5),'safety_orange',p)
    pivot('Socket_Berth_'+str(side),(x,y,-8))

def lotus():
    # Swept launch wings + an open, ribbed hangar and tall asymmetric beacon.
    box('Open hangar floor',(0,29,-18),(111,191,10),'enamel_teal')
    arch('Petal barrel hangar',37,112,77,136)
    box('Rear pressure door',(0,104,22),(94,5,53),'structural_dark')
    for x in [-28,0,28]:box('Door leaves',(x,101,22),(24,3,47),'edge_steel')
    for x in [-47,47]:light_bar('Hangar entrance glow',(x,-34,15),(2,2,38))
    for side in [-1,1]:
        for y in [-17,37]:
            beam('Swept launch truss',(side*43,y,-25),(side*145,y-42,-25),4,'enamel_teal')
        landing_deck(side,'lotus')
        for y in [9,64]:freight_pod((side*23,y,0),'enamel_teal')
    # Three light petal radiators behind the departure apron.
    for x in [-72,0,72]:
        beam('Petal array hinge',(0,111,-24),(x,177,-24),4)
        o=box('Rounded support petal',(x,172,-22),(58,98,7));o.rotation_euler.z=-x/260
        photovoltaic(x,172,-17,48,80)
    cyl('Rescue beacon foot',(-75,78,7),15,52,'enamel_teal')
    beam('Offset communication mast',(-75,78,22),(-75,78,145),3)
    for z,r in [(105,22),(137,16)]:torus('Navigation transponder',(-75,78,z),r,2.5,'enamel_cream')
    light_bar('Beacon transmitter',(-75,78,149),(5,5,9))
    # Gate identity stays above the opening; roof identity reads from overhead approach.
    box('Lotus gate sign',(0,-33,57),(48,4,24),'enamel_teal')
    marks.mount('Lotus hangar identity','lotus',(0,-36,57),(1,0,0),(0,0,1),24)
    marks.mount('Lotus hangar roof','lotus',(0,37,78),(1,0,0),(0,1,0),32)

def ore_bin(p):
    x,y,z=p
    cyl('Ore bin lower tank',p,25,66,'edge_steel')
    for dz in [-26,26]:torus('Ore bin clamp',(x,y,z+dz),25,2,'safety_orange')
    bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=10,radius2=25,depth=27,location=(x,y,z-46));finish(bpy.context.object,'Gravity feed funnel','structural_dark',1)
    cyl('Feed valve',(x,y,z-65),10,10,'safety_orange')
    for side in [-1,1]:beam('Bin support',(x+side*29,y,z+25),(x+side*29,y,z-82),3,'structural_dark')

def mine():
    # Long exposed processing rack, vertical silos, conveyors and a robot service rack.
    for x in [-42,42]:
        box('Open foundry longitudinal frame',(x,51,-35),(12,303,17),'structural_dark')
        for y in [-73,-8,57,122,187]:beam('Foundry diagonal',(x,y,-27),(-x,y+35,-27),3,'edge_steel')
    for side in [-1,1]:
        beam('Dock outrigger',(side*40,-45,-26),(side*149,-45,-26),8,'edge_steel')
        landing_deck(side,'mine')
    for y in [84,153]:ore_bin((0,y,65))
    box('Conveyor bed',(0,12,-5),(32,140,12),'structural_dark')
    rotor=pivot('Anim_Sorter',(0,-2,9))
    for x in [-17,17]:
        beam('Conveyor retaining rail',(x,-59,4),(x,74,4),2,'safety_orange')
    for y in range(-54,70,9):
        o=cyl('Conveyor roller',(0,y,4),3,31);o.rotation_euler.y=math.pi*.5
    for x in [-43,43]:
        box('Sorting gantry column',(x,-12,43),(13,20,131),'edge_steel')
        for y in [-10,10]:beam('Sorting hydraulic rail',(x,y-12,-12),(x,y-12,95),2,'safety_orange')
    box('Sorting gantry crown',(0,-12,108),(108,30,17),'structural_dark')
    for i in range(6):box('Sorter teeth',(i*7-17,0,0),(4,19,9),'safety_orange',rotor)
    for side in [-1,1]:
        x=side*79
        box('Robot service shelf',(x,135,-5),(40,72,9),'edge_steel')
        for y in [114,139,164]:
            box('Machine spare cassette',(x,y,10),(29,20,22),'enamel_teal')
            box('Service hatch',(x-side*16,y,10),(3,13,13),'safety_orange')
        beam('Rack service arm',(x,171,-3),(x,171,61),4)
        beam('Rack hydraulic elbow',(x,171,61),(x-side*23,144,36),3,'safety_orange')
    box('Mine forward machine housing',(0,-77,24),(65,24,47),'enamel_teal')
    marks.mount('Mine processing identity','mine',(0,-90,25),(1,0,0),(0,0,1),37)
    marks.mount('Mine gantry roof','mine',(0,-12,118),(1,0,0),(0,1,0),27)
    for side in [-1,1]:photovoltaic(side*84,55,-36,43,55)

def coopertech():
    # Low octagonal fortress, protected isolated test aperture and sealed robot vaults.
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=108,depth=36,location=(0,39,1));h=bpy.context.object;h.rotation_euler.z=math.pi/8;finish(h,'Octagonal blast citadel','structural_dark',2)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=103,depth=7,location=(0,39,22));finish(bpy.context.object,'Citadel armor cap','edge_steel',1)
    for side in [-1,1]:
        beam('Sealed transfer tunnel',(side*49,-15,-19),(side*144,-15,-19),15,'structural_dark')
        landing_deck(side,'coopertech')
        o=box('Sloped vault armor',(side*61,51,49),(39,108,56),'structural_dark');o.rotation_euler.y=-side*.27
        box('Vault inner steel',(side*45,47,58),(20,88,29),'edge_steel')
        for y in [6,43,80]:box('Vault interlock',(side*41,y,76),(24,5,7),'safety_orange')
        for y in [-20,15,50,85]:
            box('Armored hinge',(side*90,y,28),(8,14,13),'edge_steel')
        for y in [5,44,83]:
            box('Sealed combat unit container',(side*34,y,35),(17,30,19),'edge_steel')
            box('Container tamper seal',(side*34,y-16,36),(5,2,14),'safety_orange')
    # Circular recessed calibration bay: shutter stays closed, tests are a later interaction.
    cyl('Isolated test well',(0,38,30),31,16,'structural_dark')
    torus('Calibration aperture armor',(0,38,42),32,6,'edge_steel')
    for side in [-1,1]:box('Closed test shutter',(side*13,38,39),(25,43,3),'structural_dark')
    for y in [22,38,54]:box('Shutter locking bars',(0,y,43),(26,3,3),'safety_orange')
    box('Command bastion',(0,131,48),(61,38,69),'structural_dark')
    box('Command visor',(0,110,67),(47,4,8),'edge_steel');light_bar('Protected sensor slit',(0,107,67),(35,2,3))
    sensor=pivot('Anim_SecuritySensor',(0,131,93))
    cyl('Sensor armored head',(0,0,0),14,16,'structural_dark',sensor)
    box('Sensor lens',(0,-14,0),(17,3,4),'enamel_teal',sensor)
    for side in [-1,1]:
        o=box('Rear radiator shield',(side*76,155,2),(36,75,9),'structural_dark');o.rotation_euler.y=side*.45
        for y in [130,144,158,172]:box('Recessed heat exhaust',(side*76,y,8),(25,5,3),'edge_steel')
    box('Combat robotics identity shield',(0,-63,17),(56,8,47),'structural_dark')
    marks.mount('CooperTech armored gate','coopertech',(0,-68,18),(1,0,0),(0,0,1),39)
    marks.mount('CooperTech command roof','coopertech',(0,131,84),(1,0,0),(0,1,0),31)

def retired():
    # Broken radial hub: one detached arm and collapsed arrays, no live cargo machinery.
    cyl('Abandoned open service drum',(0,0,-3),43,69,'structural_dark')
    for z in [-30,25]:torus('Exposed hull fracture rim',(0,0,z),45,5,'edge_steel')
    for a in [0,.5,1.2,2.8,3.5,4.0,5.0]:
        x,y=math.cos(a)*43,math.sin(a)*43
        o=box('Remaining pressure panels',(x,y,0),(27,5,43));o.rotation_euler.z=a-math.pi*.5
    for side in [-1,1]:
        end=side*93
        for y in [-12,12]:beam('Exposed fractured truss',(side*32,y,-24),(end,y-22,-24),3)
        # Narrow plates mark stranded berths, unlike any active company's machinery.
        x=side*151
        box('Stranded mooring keel',(x,-38,-29),(22,133,13),'structural_dark')
        for y in [-76,-38,0]:
            o=box('Buckled mooring plate',(x,y,-20),(65,21,4),'edge_steel');o.rotation_euler.y=side*.14
        pivot('Socket_Berth_'+str(side),(x,-38,-8))
        for angle in [-.5,.5]:
            o=box('Closed dock cross',(x,-38,-14),(40,3,2),'safety_orange');o.rotation_euler.z=angle
    for x,y,a in [(-61,86,.25),(61,102,-.5),(20,-105,.6)]:
        beam('Bent radiator boom',(0,0,-34),(x,y,-34),3)
        before=set(bpy.context.scene.objects);photovoltaic(x,y,-31,72,53)
        for o in set(bpy.context.scene.objects)-before:o.rotation_euler.y=a
    for i in range(6):
        o=box('Loose armored debris',(92+i*11,46+i*6,-6+i*5),(11,9,3),'edge_steel');o.rotation_euler=(i*.3,i*.2,i*.6)
    box('Blank decommissioned identity',(0,-44,7),(39,4,31),'structural_dark')
    for a in [-.7,.7]:
        o=box('Removed operator mark',(0,-47,7),(27,3,3),'safety_orange');o.rotation_euler.y=a

records=[]
for company,build in [('lotus',lotus),('mine',mine),('coopertech',coopertech),('retired',retired)]:
    bpy.ops.wm.read_factory_settings(use_empty=True);SIGNAL=signal_material();build()
    row=export('relay_'+company);row['generator']='tools/build_corporate_relays.py';row['design_revision']=2;row['purpose']={'lotus':'expedition supply and launch hangar','mine':'ore collection, sorting and machine service','coopertech':'armored combat robotics calibration and sealed transfer','retired':'withdrawn logistics remains'}[company];records.append(row)
(SOURCE/'corporate_relays.json').write_text(json.dumps(records,indent=2)+'\n')
