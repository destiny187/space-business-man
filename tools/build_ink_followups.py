"""Finish the 16 remaining legacy meshes using editable Blender authoring.

Use -- followed by IDs to regenerate only changed assets. No gameplay IDs change.
"""
from pathlib import Path
import bpy
import json
import math
import random
import sys
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as g
import ink_blender as ink

KINDS=['base','factory','charger','solar','reactor','surveyor','guardian','manual_tool',
       'ruin','microbe','animal','civilization','tree','mesa_0','mesa_1','mesa_2']
REVIEW=ROOT/'docs/production/media/ink-followups'
REVIEW.mkdir(parents=True,exist_ok=True)
box,cyl,ring,rod,pipe,pivot=g.box,g.cyl,g.ring,g.rod,g.pipe,g.pivot


def material(role,color,rough=.75,metal=0,glow=0):
    m=bpy.data.materials.new('Field '+role);m.use_nodes=True;m.diffuse_color=(*color,1)
    b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=m.diffuse_color
    b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
    if glow:b.inputs['Emission Color'].default_value=m.diffuse_color;b.inputs['Emission Strength'].default_value=glow
    g.P[role]=m
    return m


def uv(name,loc,size,role,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=loc)
    o=bpy.context.object;o.scale=size
    return g.finish(o,name,role,0,parent)


def mesh(name,verts,faces,role,smooth=False):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(g.P[role])
    for face in data.polygons:face.use_smooth=smooth
    return obj


def foundation(size=3.6):
    box('Bearing plinth',(0,0,.13),(size,size,.26),'dark',.09)
    box('Service apron',(0,0,.29),(size-.18,size-.18,.12),'steel',.04)
    for x in [-size/2+.20,size/2-.20]:
        for y in [-size/2+.20,size/2-.20]:cyl('Foundation anchor',(x,y,.38),.085,.09,'orange')


def door(x,y,z,width,height):
    box('Airlock recess',(x,y,z),(width+.20,.10,height+.17),'dark',.09)
    for side in [-1,1]:
        box('Split access door',(x+side*width*.25,y-.075,z),(width*.47,.075,height),'teal',.055)
        box('Door pull',(x+side*.15,y-.133,z),(.07,.07,.31),'orange',.025)
    box('Door overhead lamp',(x,y-.12,z+height*.5+.07),(width*.70,.055,.05),'status',.012)


def base():
    foundation(5.4)
    box('Control cabin seal',(0,.12,1.56),(4.17,2.66,2.34),'dark',.22)
    box('Control cabin armour',(0,.12,1.58),(4.24,2.75,2.41),'cream',.22)
    box('Roof gasket',(0,.12,2.82),(4.39,2.90,.10),'dark',.04)
    box('Service roof',(0,.12,2.94),(4.48,2.99,.19),'teal',.10)
    door(-.66,-1.29,1.41,1.2,1.85)
    box('Observation window surround',(1.11,-1.31,1.86),(1.27,.09,.86),'dark',.16)
    box('Recessed blue observation window',(1.11,-1.37,1.86),(1.08,.04,.68),'water',.13)
    box('Window sun hood',(1.11,-1.50,2.38),(1.45,.36,.11),'cream',.05)
    for x in [-2.02,2.02]:
        box('Cabin corner frame',(x,-1.22,1.58),(.18,.20,2.19),'steel',.06)
        box('Side maintenance panel',(x*1.06,.14,1.60),(.08,1.46,1.24),'teal',.055)
        for z in [1.25,1.53,1.81]:box('Cabin ventilation louvre',(x*1.085,.21,z),(.07,.90,.075),'dark',.02)
    for y,z in [(-1.71,.41),(-2.02,.37)]:box('Airlock tread',(-.66,y,z),(1.6,.37,.16),'steel',.035)
    for x in [-1.64,.33]:
        pipe('Access handrail',[(x,-1.92,.46),(x,-1.92,1.15),(x,-1.25,1.29)],.046,'orange')
    cyl('Mast foot',(1.6,.7,3.10),.22,.26,'dark')
    cyl('Comms mast',(1.6,.7,3.92),.075,1.50,'steel')
    uv('Comms beacon',(1.6,.7,4.73),(.11,.11,.15),'status')
    for z in [3.6,4.0]:rod('Antenna crossbar',(1.18,.7,z),(2.02,.7,z),.032,'steel')
    box('Roof equipment crate',(-1.16,.54,3.15),(1.05,.91,.27),'cream',.10)
    for x in [-1.50,-1.16,-.82]:box('Equipment intake',(x,.54,3.30),(.10,.66,.02),'dark',.01)


def factory():
    foundation()
    # Actual recessed assembly bay, floor tracks, rear tools and service side pods.
    box('Assembly bed',(0,.02,.49),(2.9,2.83,.27),'dark',.09)
    box('Rear enclosure',(0,1.17,1.83),(2.8,.40,2.69),'cream',.13)
    for side in [-1,1]:
        x=side*1.12
        box('Service side pod',(x,0,1.78),(.63,2.54,2.45),'cream',.13)
        box('Pod front inset',(x,-1.30,1.55),(.47,.07,1.59),'teal',.05)
        box('Safety handle',(x,-1.36,1.60),(.10,.065,.38),'orange',.025)
        box('Assembly guide rail',(side*.47,-.05,.67),(.12,2.43,.12),'steel',.025)
        box('Enclosure inner frame',(side*.77,-.2,1.93),(.10,2.23,2.25),'dark',.03)
        for z in [1.20,1.55,1.90]:box('Side heat louvre',(side*1.47,.18,z),(.05,.98,.12),'dark',.025)
    box('Overhead gantry',(0,-.12,2.96),(2.89,2.77,.28),'teal',.09)
    box('Gantry crossbeam',(0,-.33,2.71),(1.63,.26,.18),'steel',.04)
    cyl('Tool spindle',(0,-.33,2.40),.11,.51,'dark')
    box('Assembly tool head',(0,-.33,2.17),(.42,.37,.22),'orange',.065)
    for x in [-.16,.16]:rod('Gripper jaw',(x,-.33,2.08),(x,-.33,1.93),.045,'steel')
    box('Robot mounting platform',(0,.19,.80),(1.25,1.31,.19),'steel',.055)
    box('Rear tooling wall',(0,.934,1.76),(1.20,.035,1.40),'dark',.035)
    for x in [-.4,0,.4]:box('Tool cassette',(x,.893,1.88),(.22,.08,.73),'teal',.045)
    box('Front gantry identity plate',(0,-1.533,2.93),(1.34,.05,.17),'cream',.025)
    for x in [-.66,.66]:box('Bay guide light',(x,-1.45,1.60),(.05,.04,1.48),'status',.01)
    box('Approach ramp',(0,-1.60,.43),(1.54,.36,.17),'steel',.035)


def charger():
    foundation()
    cyl('Charging deck',(0,-.14,.44),1.22,.18,'dark')
    cyl('Insulated charging surface',(0,-.14,.54),1.10,.10,'teal')
    for side in [-1,1]:
        box('Conductive wheel strip',(side*.65,-.14,.615),(.25,1.52,.08),'steel',.045)
        box('Rear wheel stop',(side*.65,.64,.70),(.39,.16,.18),'orange',.04)
        for y in [-1.0,-.57,-.14,.29]:box('Alignment chevron',(side*1.03,y,.58),(.09,.14,.035),'status',.02)
    box('Charger terminal foot',(1.2,1.2,.46),(.67,.65,.22),'dark',.08)
    box('Charging power pedestal',(1.2,1.2,1.04),(.55,.52,1.09),'cream',.10)
    box('Terminal collar',(1.2,1.2,1.59),(.66,.59,.19),'teal',.08)
    box('Charging display',(1.2,.926,1.19),(.38,.03,.37),'dark',.035)
    for z in [1.09,1.20,1.31]:box('Charging state bar',(1.2,.901,z),(.23,.025,.046),'status',.008)
    pipe('Shielded charging lead',[(1.13,1.13,.83),(.63,1.40,.56),(.13,1.19,.48)],.065,'rubber')
    cyl('Power connector',(.14,1.02,.51),.13,.25,'orange',(math.pi/2,0,0))


def solar():
    foundation()
    material('solar_cell',(.028,.10,.22),.36,.30)
    cyl('Azimuth mount',(0,0,.58),.38,.43,'dark')
    cyl('Array pedestal',(0,0,1.09),.20,.94,'steel')
    box('Panel bearing',(0,0,1.54),(.98,.59,.30),'teal',.09)
    # Preserve the existing 4.1 by 2.8m array envelope and horizontal collector plane.
    box('Rounded panel backplate',(0,0,1.80),(4.1,2.8,.16),'cream',.075)
    box('Inset cell substrate',(0,0,1.90),(3.92,2.61,.06),'dark',.035)
    for x in [-1.45,-.48,.48,1.45]:
        for y in [-.85,0,.85]:
            box('Photovoltaic module',(x,y,1.97),(.90,.76,.065),'solar_cell',.035)
            box('Module busbar',(x,y,2.008),(.68,.018,.008),'steel',.003)
    for x in [-1.78,1.78]:
        box('Outer load rail',(x,0,1.66),(.12,2.69,.16),'steel',.025)
        rod('Array support strut',(x,0,1.59),(0,0,1.05),.065,'steel')
    box('Inverter housing',(0,.92,.68),(1.05,.60,.56),'teal',.09)
    pipe('Power trunk',[(0,.05,1.56),(0,.39,.96),(0,.83,.87)],.054,'rubber')


def reactor():
    foundation()
    material('reactor_core',(.34,.17,.56),.33,.15,.15)
    cyl('Containment footing',(0,0,.61),1.12,.51,'dark')
    cyl('Shielding drum',(0,0,1.34),1.00,1.04,'cream')
    for z in [.87,1.88]:ring('Shield retaining band',(0,0,z),1.02,.065,'steel')
    cyl('Core well',(0,0,2.09),.76,.40,'dark')
    uv('Core lower envelope',(0,0,2.70),(.54,.54,.60),'reactor_core')
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(0,0,3.45))
    ob=bpy.context.object;ob.scale=(.43,.43,.72);g.finish(ob,'Faceted containment core','reactor_core')
    for i in range(3):
        a=i*math.tau/3+math.pi/2;x,y=math.cos(a),math.sin(a)
        rod('Containment load arm',(x*.89,y*.89,1.47),(x*.96,y*.96,3.64),.105,'cream')
        box('Containment emitter',(x*.89,y*.89,3.66),(.24,.24,.55),'teal',.06)
        rod('Field terminal',(x*.85,y*.85,3.90),(x*.58,y*.58,3.80),.065,'status')
    ring('Containment field coil',(0,0,2.81),.75,.045,'steel')
    g.terminal(0,-1.07,1.07)


def delete_prefixes(prefixes):
    targets=[o for o in bpy.context.scene.objects if o.name.startswith(tuple(prefixes))]
    targets += [child for obj in targets for child in obj.children_recursive]
    for name in {o.name for o in targets}:
        ob=bpy.data.objects.get(name)
        if ob:bpy.data.objects.remove(ob,do_unlink=True)


def surveyor():
    g.miner()
    # Shared locomotion family, independent survey mast; the existing sample drill stays.
    box('Survey equipment pack',(.19,.58,1.60),(.86,.54,.30),'teal',.08)
    rod('Survey mast',(.22,.58,1.7),(.22,.58,2.28),.052,'steel')
    cyl('Survey sensor cradle',(.22,.58,2.20),.16,.21,'dark')
    box('Wide mineral scanner',(.22,.55,2.32),(.88,.44,.23),'cream',.10)
    for x in [-.07,.22,.51]:
        cyl('Scanner aperture',(x,.31,2.32),.076,.035,'dark',(math.pi/2,0,0))
        cyl('Scanner lens',(x,.287,2.32),.047,.022,'water',(math.pi/2,0,0))
    for x in [-.32,.62]:box('Sample cartridge',(x,.94,1.40),(.26,.32,.25),'orange',.055)


def guardian():
    g.miner()
    delete_prefixes(['ToolRotor','Arm knuckle','Knuckle end cap','Arm casting','Drill feed housing',
                     'Polished feed piston','Hydraulic hose','Drill protective collar','Sensor neck',
                     'Sensor head','Recessed visor','Optical lens bezel','Survey optic'])
    turret=pivot('Anim_Turret',(0,0,1.76))
    cyl('Turret bearing',(0,0,1.59),.43,.16,'dark')
    box('Rounded sentry turret',(0,0,1.83),(.96,.95,.45),'cream',.15,turret)
    box('Turret rear shield',(0,.40,1.84),(.80,.16,.28),'teal',.06,turret)
    box('Targeting visor',(0,-.49,1.98),(.40,.06,.10),'dark',.035,turret)
    box('Target optic',(0,-.53,1.98),(.15,.025,.048),'status',.01,turret)
    for x in [-.22,.22]:
        barrel=pivot('Anim_Barrel_%s'%x,(x,-.82,1.81),(math.pi/2,0,0))
        cyl('Barrel sleeve',(x,-.62,1.81),.112,.70,'teal',(math.pi/2,0,0),barrel)
        cyl('Pulse barrel',(x,-1.14,1.81),.072,.52,'steel',(math.pi/2,0,0),barrel)
        ring('Muzzle collar',(x,-1.42,1.81),.102,.028,'cream',(math.pi/2,0,0),barrel)
        cyl('Recessed muzzle',(x,-1.443,1.81),.070,.020,'dark',(math.pi/2,0,0),barrel)
        for y in [-.51,-.68,-.85]:ring('Barrel heat sink',(x,y,1.81),.117,.021,'steel',(math.pi/2,0,0),barrel)


def manual_tool():
    # Preserve all four original moving node transforms, intake and hand grip envelope.
    box('Ergonomic insulated grip',(0,-.18,-.22),(.22,.30,.46),'rubber',.07)
    for z in [-.35,-.25,-.15]:box('Grip rib',(0,-.343,z),(.16,.04,.035),'dark',.015)
    box('Trigger bridge',(0,.00,-.26),(.10,.08,.14),'orange',.025)
    box('Induction body',(0,.055,0),(.48,.72,.36),'teal',.12)
    box('Housing lower seal',(0,.04,-.17),(.44,.64,.06),'dark',.025)
    box('Ceramic upper housing',(0,.02,.20),(.42,.61,.09),'cream',.045)
    box('Inlaid charge display',(0,-.03,.252),(.26,.21,.028),'dark',.022)
    for i in range(4):box('Charge segment',(-.075+i*.05,-.02,.271),(.024,.095,.009),'status',.004)
    cyl('Vacuum barrel',(0,.51,0),.20,.40,'steel',(math.pi/2,0,0))
    cyl('Deep intake well',(0,.753,0),.205,.018,'dark',(math.pi/2,0,0))
    collar=pivot('Anim_Collar',(0,.69,0),(math.pi/2,0,0))
    ring('Moving collar',(0,.69,0),.218,.025,'orange',(math.pi/2,0,0),collar)
    ring('Ceramic intake lip',(0,.76,0),.227,.025,'cream',(math.pi/2,0,0))
    ring('Induction halo',(0,.775,0),.17,.018,'status',(math.pi/2,0,0))
    rotor=pivot('Anim_Fan',(0,.778,0))
    for i in range(5):
        a=i*math.tau/5
        o=box('Intake impeller blade',(math.cos(a)*.075,.778,math.sin(a)*.075),(.16,.018,.031),'teal',.008,rotor)
        o.rotation_euler.y=-a
    cyl('Induction core',(0,.796,0),.046,.025,'status',(math.pi/2,0,0))
    for x in [-.27,.27]:
        box('Intake protective rail',(x,.35,0),(.055,.69,.29),'dark',.035)
        piston=pivot('Anim_Piston_%s'%x,(x,.21,.19),(math.pi/2,0,0))
        cyl('Piston rod',(x,.21,.19),.036,.42,'steel',(math.pi/2,0,0),piston)
        cyl('Piston guide',(x,.03,.19),.052,.12,'orange',(math.pi/2,0,0))
        for y in [-.14,-.035,.07]:box('Cooling grille',(x*.91,y,.02),(.024,.05,.15),'cream',.007)
        cyl('Service latch',(x*.92,-.24,.05),.042,.025,'orange',(0,math.pi/2,0))
    pipe('Power return',[(-.19,.44,-.16),(-.19,.20,-.24),(-.15,-.11,-.23)],.024,'rubber')


def natural_palette():
    material('stone',(.24,.19,.17))
    material('stone_light',(.41,.33,.27))
    material('stone_dark',(.10,.13,.14))
    material('moss',(.13,.26,.15))
    material('bark',(.16,.095,.065))
    material('leaf',(.15,.34,.17))
    material('leaf_light',(.27,.43,.19))
    material('hide',(.18,.36,.31))
    material('belly',(.56,.58,.39))
    material('eye',(.018,.029,.031),.30)
    material('spore',(.12,.56,.47),.48,0,.12)
    material('ancient',(.31,.17,.43),.52,.12)


def rock(name,loc,size,role,seed=0):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    ob=bpy.context.object;ob.name=name
    for vert in ob.data.vertices:
        v=vert.co;v*=rng.uniform(.88,1.12)
        v.x*=size[0];v.y*=size[1];v.z*=size[2]
    ob.data.materials.append(g.P[role]);return ob


def leaf(name,start,end,width,role):
    a,b=Vector(start),Vector(end);d=b-a
    side=d.cross(Vector((0,0,1)))
    if side.length<.01:side=Vector((1,0,0))
    side.normalize();verts=[]
    # Solid curved lanceolate blade: visible thickness and quiet broad surfaces.
    for row in range(7):
        t=row/6;center=a+d*t+Vector((0,0,math.sin(t*math.pi)*width*.34))
        w=math.sin(t*math.pi)**.75*width
        for offset in [-1,0,1]:verts.append(tuple(center+side*w*offset+Vector((0,0,(1-abs(offset))*w*.16))))
    faces=[]
    for row in range(6):
        for col in range(2):n=row*3+col;faces.append((n,n+1,n+4,n+3))
    ob=mesh(name,verts,faces,role,True)
    solid=ob.modifiers.new('Leaf thickness','SOLIDIFY');solid.thickness=max(.018,width*.07)
    return ob


def ruin():
    natural_palette()
    # Broken interlocking stonework keeps the recognisable portal and open centre.
    for side in [-1,1]:
        for i in range(4):
            x=side*(1.18+.045*math.sin(i));z=.48+i*.82
            ob=box('Ancient bearing block',(x,0,z),(.92,1.03,.77),'stone',.075)
            ob.rotation_euler.z=side*(.02 if i%2 else -.015)
            if i<3:box('Carved recess',(x,-.53,z),(.52,.045,.18),'stone_dark',.025)
        box('Portal capital',(side*1.18,0,3.47),(1.14,1.13,.27),'stone_light',.05)
    box('Interlocked lintel',(0,0,3.75),(3.55,1.06,.40),'stone',.07)
    box('Lintel relief',(0,-.55,3.73),(1.46,.06,.16),'stone_light',.03)
    for x in [-.47,0,.47]:box('Recessed ancient rune',(x,-.59,3.73),(.08,.022,.14),'ancient',.015)
    cyl('Relic socket',(0,0,.40),.60,.36,'stone_dark')
    rock('Relic crystal',(0,0,1.03),(.33,.30,.59),'ancient',8)
    for i in range(8):
        a=i*2.4;x=math.cos(a)*1.55;y=math.sin(a)*.80
        rock('Weathered fallen stone',(x,y,.15),(.24,.19,.15),'stone_light',i)
    for side in [-1,1]:leaf('Moss blade',(side*1.38,-.32,.31),(side*1.48,-.27,.76),.12,'moss')


def microbe():
    natural_palette()
    uv('Microbial mat',(0,0,.09),(1.67,1.51,.15),'moss')
    # Clearly differentiated vesicles, membranes and linking filaments.
    for i in range(9):
        a=i*2.39996;r=.34+(.82 if i>2 else .15)
        x,y=math.cos(a)*r,math.sin(a)*r;h=.21+.07*(i%3)
        uv('Colony vesicle',(x,y,h+.12),(.22+.03*(i%2),.23,h),'hide')
        ring('Vesicle membrane ridge',(x,y,h+.16),.20,.022,'spore')
        uv('Colony nucleus',(x-.035,y-.06,2*h+.13),(.085,.09,.07),'spore')
        pipe('Colony filament',[(0,0,.255),(x*.5,y*.5,.26),(x,y,.20)],.028,'spore')


def animal():
    natural_palette()
    # Preserve the original Mossling body scale and whole-body procedural motion.
    uv('Mossling torso',(0,.05,.89),(.72,.98,.60),'hide')
    uv('Mossling breast',(0,-.48,.72),(.58,.61,.48),'belly')
    uv('Mossling head',(0,-.90,1.16),(.55,.54,.47),'hide')
    uv('Soft muzzle',(0,-1.34,1.00),(.40,.24,.24),'belly')
    for side in [-1,1]:
        uv('Eye socket',(side*.28,-1.35,1.31),(.17,.105,.18),'belly')
        uv('Obsidian eye',(side*.28,-1.432,1.32),(.105,.057,.116),'eye')
        uv('Eye reflection',(side*.28-.025,-1.48,1.36),(.025,.012,.032),'cream')
        uv('Nostril',(side*.12,-1.554,1.02),(.045,.024,.026),'eye')
        leaf('Sensory ear',(side*.31,-.79,1.47),(side*.60,-.70,2.06),.16,'hide')
        leaf('Ear inner blade',(side*.32,-.82,1.51),(side*.58,-.74,1.99),.089,'belly')
        for y in [-.51,.67]:
            uv('Haunch',(side*.54,y,.52),(.27,.33,.34),'hide')
            uv('Broad foot',(side*.54,y-.07,.18),(.23,.31,.17),'belly')
            for k in [-1,0,1]:uv('Toe',(side*.54+k*.095,y-.31,.17),(.068,.12,.08),'stone_dark')
    pipe('Mossling tail',[(0,.75,.79),(0,1.10,.66),(.35,1.38,.60),(.58,1.47,.79)],.13,'hide')
    for i in range(5):
        y=-.18+i*.23
        leaf('Dorsal leaf fin',(0,y,1.40),(0,y+.18,1.70-.045*i),.15,'moss')


def civilization():
    natural_palette()
    material('clay',(.47,.35,.23))
    material('roof',(.13,.30,.29))
    for i in range(5):
        a=i*math.tau/5;x,y=math.cos(a)*1.6,math.sin(a)*1.6
        cyl('Settlement footing',(x,y,.14),.71,.27,'stone_dark')
        cyl('Clay dwelling',(x,y,.70),.61,1.03,'clay')
        uv('Arched weather roof',(x,y,1.27),(.73,.73,.33),'roof')
        ring('Eave edge',(x,y,1.24),.70,.045,'stone_light')
        box('Dwelling doorway',(x,y-.604,.57),(.30,.06,.54),'stone_dark',.12)
        box('Door sill',(x,y-.69,.22),(.40,.27,.12),'stone_light',.025)
        for xx in [-.34,.34]:box('Dwelling window',(x+xx,y-.54,.84),(.13,.045,.19),'spore',.04)
        cyl('Roof vent',(x+.24,y+.10,1.54),.11,.30,'stone_light')
    cyl('Communal signal base',(0,0,.27),.55,.36,'stone_dark')
    cyl('Signal core',(0,0,1.80),.13,2.84,'ancient')
    for z in [1.0,2.3,3.20]:ring('Signal collar',(0,0,z),.24,.046,'stone_light')
    uv('Settlement beacon',(0,0,3.54),(.23,.23,.30),'spore')
    for i in range(5):
        a=i*math.tau/5
        box('Path stone',(math.cos(a)*.83,math.sin(a)*.83,.07),(.43,.43,.10),'stone_light',.07)


def tree():
    natural_palette()
    pipe('Bent trunk',[(0,0,.02),(.10,.04,.72),(-.03,.05,1.50),(.06,0,2.16)],.13,'bark')
    for i in range(7):
        a=i*2.39996;z=1.03+(i%3)*.39
        end=(math.cos(a)*(.58 if i<4 else .48),math.sin(a)*(.58 if i<4 else .48),z+.35)
        rod('Branch',(0,0,z),end,.045,'bark')
        for k in range(5):
            b=a+(k-2)*.64;length=.57 if i<4 else .49
            leaf('Canopy blade',end,(end[0]+math.cos(b)*length,end[1]+math.sin(b)*length,end[2]+.28-(k%2)*.12),.21,'leaf' if k%2 else 'leaf_light')
    for i in range(5):
        a=i*math.tau/5
        leaf('Crown leaf',(.04,0,2.1),(math.cos(a)*.5,math.sin(a)*.5,2.72),.22,'leaf_light')
        rod('Exposed root',(0,0,.16),(math.cos(a)*.33,math.sin(a)*.33,.03),.064,'bark')


def mesa(variant):
    natural_palette();rng=random.Random(9031+variant*113)
    # Coherent broad beds with erosional shoulders; avoid noisy triangulated rings.
    def tower(name,center,rx,ry,height,phase):
        count=32
        angles=[i*math.tau/count for i in range(count)]
        radial=[1+.08*math.sin(a*3+phase)+.035*math.sin(a*7-phase) for a in angles]
        levels=[(0,1.14),(.10,1.09),(.13,1.02),(.34,.97),(.37,1.00),(.60,.82),(.64,.85),(.88,.71),(1,.64)]
        verts=[]
        for z,w in levels:
            for i,a in enumerate(angles):
                verts.append((center[0]+math.cos(a)*rx*radial[i]*w+z*rx*.10,
                              center[1]+math.sin(a)*ry*radial[i]*w,
                              height*z*(1+.018*math.sin(a*3+phase))))
        faces=[tuple(reversed(range(count)))]
        for n in range(len(levels)-1):
            for i in range(count):faces.append((n*count+i,n*count+(i+1)%count,(n+1)*count+(i+1)%count,(n+1)*count+i))
        faces.append(tuple((len(levels)-1)*count+i for i in range(count)))
        ob=mesh(name,verts,faces,'stone')
        # Planar broad beds deliberately retain angular weathered stone normals.
        return ob
    height=22+variant*4
    if variant==0:
        tower('Layered broad crown',(0,0),8.9,7.2,height,.2)
        for i in range(3):
            a=i*2.1;tower('Eroded buttress',(math.cos(a)*8,math.sin(a)*7),4.2,3.4,11+i*2,i+.7)
    elif variant==1:
        tower('Split west crown',(-4.3,0),5.4,7.0,height,1.1)
        tower('Split east crown',(4.6,1.1),4.7,6.1,height*.86,2.4)
        tower('Broken foreland',(0,-7),6.5,3.3,10,.4)
    else:
        tower('Leaning central spire',(0,0),6.2,5.0,height,2.1)
        tower('High shoulder',(-6,2),4.0,4.6,height*.71,.3)
        tower('Low shoulder',(6,-3),4.3,3.8,height*.42,1.7)
    for i in range(7):
        a=rng.random()*math.tau
        rock('Talus slab',(math.cos(a)*10,math.sin(a)*8,.35),
             (rng.uniform(.6,1.3),rng.uniform(.5,1),.55),'stone',variant*17+i)


def render(kind):
    scene=bpy.context.scene;points=[]
    for o in scene.objects:
        if o.type=='MESH':points.extend(o.matrix_world@Vector(c) for c in o.bound_box)
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(low+high)*.5;size=high-low;radius=size.length
    scene.world=bpy.data.worlds.new('Temporary followup review');scene.world.color=(.16,.16,.16)
    box('Review floor',(0,0,low.z-.06),(max(200,radius*12),)*2+(.08,),'cream',0)
    bpy.ops.object.camera_add(location=center+Vector((1.22,-1.70,.84)).normalized()*radius*2.4)
    camera=bpy.context.object;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=radius*1.04;camera.data.clip_end=max(1000,radius*10);scene.camera=camera
    for pos,energy in [((.5,-.8,1.1),75),((-.8,-.25,.7),35)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(pos)*radius)
        light=bpy.context.object;light.data.energy=energy*radius*radius;light.data.shape='DISK';light.data.size=radius*.8
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.filepath=str(REVIEW/(kind+'-blender.png'));bpy.ops.render.render(write_still=True)


def build(kind):
    g.reset()
    if kind.startswith('mesa_'):mesa(int(kind[-1]))
    else:globals()[kind]()
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.view_layer.update()
    source=ROOT/'art/blender'/('landscape' if kind.startswith('mesa_') else '')/(kind+'.blend')
    manifest_path=source.parent/'manifest.json'
    records=json.loads(manifest_path.read_text())
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    editable=sum(o.type=='MESH' for o in bpy.context.scene.objects)
    pivots={o.name:[v for row in o.matrix_world for v in row] for o in bpy.context.scene.objects if o.type=='EMPTY'}
    exported=ink.consolidate_static_surfaces();bpy.context.view_layer.update()
    for name,values in pivots.items():
        after=[v for row in bpy.data.objects[name].matrix_world for v in row]
        assert max(abs(a-b) for a,b in zip(values,after))<1e-6,name
    output=ROOT/'우주-비즈니스/assets/models'/(kind+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_apply=True,
                              export_cameras=False,export_lights=False)
    triangles=0
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    for record in records:
        if record['id']==kind:
            record.update(generator='tools/build_ink_followups.py',geometry='ink-family-remodeled',
                          material_preset=ink.PRESET['version'],editable_objects=editable,export_objects=exported,
                          triangles=triangles,motion_pivots=pivots,blender=bpy.app.version_string)
    manifest_path.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    render(kind)
    print('INK_FOLLOWUP_EXPORTED',kind,editable,exported,triangles,flush=True)


if __name__=='__main__':
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else KINDS
    if not requested:requested=KINDS
    if set(requested)-set(KINDS):raise SystemExit('Unknown followup ID')
    for kind in requested:build(kind)
