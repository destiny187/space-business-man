"""Combat gunship, secondary launcher and physical guided missile; Blender +Y forward."""
import bpy, sys, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_pirate_craft as P
F = P.F
F.CAP = ROOT / 'docs/production/media/pirate-missiles'
F.CAP.mkdir(parents=True, exist_ok=True)

def pod(parent, side, label, scale=1):
    pivot = P.pivot('Anim_Launcher_'+label, (side*2.3, 0, .5), parent)
    F.hull('Armored missile magazine', [(-3,1.6,1.35,0),(2.2,1.6,1.35,0),(3,1.2,1,0)], 'enamel_cream', pivot)
    F.box('Magazine identity stripe', (0,-.5,1.4), (2.5,2.4,.2), 'safety_orange', pivot)
    for x in [-.68,.68]:
        for z in [-.55,.55]:
            F.cylinder('Recessed launch tube', (x,2.9,z), .49, .35, 'structural_dark', pivot, 'Y')
            F.cylinder('Tube retaining collar', (x,3.05,z), .39, .12, 'edge_steel', pivot, 'Y')
    door = P.pivot('Anim_LaunchDoor_'+label, (0,3.2,1.3), pivot)
    F.box('Hinged blast cover', (0,0,-1.3), (3.1,.28,2.6), 'enamel_teal', door)
    P.pivot('Socket_Missile_'+label, (0,3.6,0), pivot)
    pivot.scale=(scale,)*3

def gunship():
    F.hull('Heavy combat spine',[(-22,4,3,0),(-12,7,4,0),(7,6,3.7,0),(19,2.5,1.2,0)],'structural_dark')
    F.hull('Sloped armored bridge',[(-6,5,2.6,3),(5,4.5,2.8,3),(16,2,1.2,1.8)],'enamel_cream')
    F.hull('Inset cockpit canopy',[(3,3.5,.6,5.6),(9,2.8,.8,4.9),(13,1.7,.5,3.5)],'enamel_teal')
    F.box('Bridge armored brow',(0,3,6.5),(7.7,1.1,.55),'enamel_cream')
    for side,label in [(-1,'L'),(1,'R')]:
        P.engine(side*7,-18,-1,3.0,label)
        wing=P.pivot('Anim_Wing_'+label,(side*5,-5,0))
        F.hull('Thick attack pylon',[(-8,4.5,.9,0),(-2,6,1.2,0),(5,3,.7,0)],'enamel_cream',wing).location.x=side*4
        mount=P.pivot('MissilePod_'+label,(side*9,2,1.5))
        pod(mount,side,label,1.65)
        flap=P.pivot('Anim_Flap_'+label,(side*9,-13,1))
        F.box('Split maneuver vane',(0,-1.3,0),(5,3,.65),'enamel_teal',flap)
        fin=F.hull('Swept vertical fin',[(-20,.45,3,2),(-12,.5,5,2),(-7,.25,1,2)],'enamel_cream')
        fin.location.x=side*5;fin.rotation_euler.y=-side*.2
        for y in [-10,-7,-4]:F.box('Armored heat exchanger',(side*4.5,y,4.4),(2.4,1,.55),'structural_dark')
    turret=P.pivot('Anim_Gun',(0,6,-2.4))
    F.hull('Ventral cannon breech',[(-2,2,1,0),(3,1.5,.8,0)],'enamel_teal',turret)
    P.weapon(turret,-1.4,2,0,.7,'L');P.weapon(turret,1.4,2,0,.7,'R')
    F.box('Reactor armor',(0,-12,4),(7,5,1.2),'safety_orange')

def launcher():
    F.cylinder('Dorsal missile hardpoint',(0,0,0),2.2,.6,'structural_dark')
    pivot=P.pivot('Anim_MissileYaw',(0,0,.6))
    F.box('Magazine carrier',(0,0,.4),(6,2.5,.9),'edge_steel',pivot)
    for side,label in [(-1,'L'),(1,'R')]:pod(pivot,side,label)

def missile():
    F.cylinder('Armored missile body',(0,0,0),.52,3.8,'enamel_cream',axis='Y')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,location=(0,2,0))
    o=bpy.context.object;o.scale=(.52,1,.52);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    F.finish(o,'Rounded guidance nose','enamel_teal',bevel=0)
    for y in [-1.5,.7]:F.cylinder('Safety collar',(0,y,0),.55,.22,'safety_orange',axis='Y')
    F.cylinder('Recessed rocket bell',(0,-2.05,0),.46,.5,'structural_dark',axis='Y')
    F.cylinder('Engine lip',(0,-2.3,0),.48,.12,'edge_steel',axis='Y')
    for i in range(4):
        fin=P.pivot('Anim_Fin_'+str(i),(0,-1,0));fin.rotation_euler.y=i*math.pi/2
        F.hull('Swept guidance fin',[(-1,.8,.08,0),(-.3,.8,.08,0),(.9,.25,.08,0)],'structural_dark',fin).location.x=.6
    P.pivot('Socket_Exhaust_Rocket',(0,-2.4,0))

records=[]
for name,build,framing in [('pirate_gunship',gunship,74),('expedition_missile_mount',launcher,14),('ship_missile',missile,8)]:
    for distant in ([False,True] if name=='pirate_gunship' else [False]):
        bpy.ops.wm.read_factory_settings(use_empty=True);F.LOD=distant;build()
        def frame(scene):scene.camera.data.ortho_scale=framing
        bpy.app.handlers.render_pre.append(frame)
        row=F.export(name+('_lod1' if distant else ''));row['revision']=1
        records.append(row);bpy.app.handlers.render_pre.remove(frame)
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']));bpy.context.scene.camera.data.ortho_scale=framing
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/row['source']))
(F.SRC/'pirate_missiles.json').write_text(json.dumps(records,indent=2)+'\n')
