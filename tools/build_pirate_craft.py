"""Pirate combat v2: authored mechanical joints and visible weapon/exhaust sockets.
Blender +Y forward. Host maneuvers drive these pivots in space_combat_view.gd.
"""
import bpy, sys, json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_space_y_freighter as F
F.CAP = ROOT / 'docs/production/media/pirate-combat'
F.CAP.mkdir(parents=True, exist_ok=True)

def pivot(name,p,parent=None):
    o=F.empty(name,p)
    if parent:o.parent=parent
    return o

def engine(x,y,z,r,side):
    F.cylinder('Pressure casing',(x,y,z),r,7,'enamel_cream',axis='Y')
    for yy in [-2.5,2.5]:F.cylinder('Engine reinforcement',(x,y+yy,z),r*1.05,.8,'edge_steel',axis='Y')
    joint=pivot('Anim_Nozzle_'+side,(x,y-4,z))
    F.cylinder('Gimballed heat shroud',(0,0,0),r*1.13,2,'structural_dark',joint,'Y')
    F.cylinder('Bell edge',(0,-1.2,0),r*1.12,.5,'edge_steel',joint,'Y')
    F.cylinder('Recessed ion throat',(0,-1.5,0),r*.7,.25,'enamel_teal',joint,'Y')
    if not F.LOD:
        for n in range(6):
            a=n*math.tau/6
            F.box('Nozzle cooling rib',(math.cos(a)*r*.95,-.4,math.sin(a)*r*.95),(.35,2,.35),'edge_steel',joint)
    pivot('Socket_Exhaust_'+side,(0,-1.8,0),joint)

def weapon(parent,x,y,z,r,side):
    F.cylinder('Fixed recuperator',(x,y-1,z),r*1.5,2.7,'edge_steel',parent,'Y')
    barrel=pivot('Anim_Barrel_'+side,(x,y,z),parent)
    F.cylinder('Pulse barrel',(0,1.8,0),r,4.8,'structural_dark',barrel,'Y')
    for yy in [.4,1.3]:F.cylinder('Barrel cooling collar',(0,yy,0),r*1.2,.3,'edge_steel',barrel,'Y')
    F.cylinder('Armored muzzle',(0,4.1,0),r*1.25,.75,'enamel_cream',barrel,'Y')
    F.cylinder('Emitter aperture',(0,4.55,0),r*.68,.18,'enamel_teal',barrel,'Y')
    pivot('Socket_Muzzle_'+side,(0,4.8,0),barrel)

def raider():
    F.hull('Armored tapered keel',[(-16,3,2,0),(-5,4.8,3,0),(8,3,2,0),(19,.5,.5,0)],'structural_dark')
    F.hull('Faceted pressure cabin',[(-8,3.9,1.8,2),(2,3.5,2,2),(12,1.8,1,1.7)],'enamel_cream')
    F.hull('Recessed cockpit glazing',[(1,2.9,.7,4),(6,2.3,.8,3.6),(11,1.3,.45,2.7)],'enamel_teal')
    F.box('Cockpit armored brow',(0,2,4.9),(5.8,1,.4),'enamel_cream')
    for s,label in [(-1,'L'),(1,'R')]:
        wing=pivot('Anim_Wing_'+label,(s*3,-3,0))
        F.hull('Swept wing', [(-11,5,.45,0),(-6,7,.65,0),(4,1.8,.45,0)],'enamel_cream',wing)
        # Offset the panel surfaces as a group to retain an actual wing root hinge.
        for o in list(wing.children):o.location.x=s*4.3
        F.box('Replaceable armor stripe',(s*7,-5,.8),(3,7,.4),'safety_orange',wing)
        flap=pivot('Anim_Flap_'+label,(s*7,-10,0),wing)
        F.box('Split trailing airbrake',(0,-1.5,0),(5,3,.65),'structural_dark',flap)
        engine(s*9,-10,-.7,2.3,label)
        fin=F.hull('Canted vertical stabilizer',[(-14, .4,3,2),(-7,.35,4.8,2),(-3,.2,.6,2)],'structural_dark')
        fin.location.x=s*7;fin.rotation_euler.y=-s*.25
    for y in [-7,-4,-1]:F.box('Dorsal radiator',(0,y,4.1),(4,.8,.4),'structural_dark')
    gun=pivot('Anim_Gun',(0,6,-1.3))
    weapon(gun,-2.6,0,0,.65,'L');weapon(gun,2.6,0,0,.65,'R')
    if not F.LOD:
        for s in [-1,1]:
            F.box('Service plate',(s*3.4,-3,2.9),(.5,5,1.4),'edge_steel')
            for y in [-5,-2]:F.cylinder('Plate fastener',(s*3,-y,3.7),.19,.15,'structural_dark')

def interdictor():
    F.hull('Broad armored tug',[(-18,6,3,0),(-9,10,4.5,0),(5,9,4.5,0),(16,4,1.7,0)],'enamel_cream')
    F.hull('Armored command wedge',[(1,5,2,4),(9,3.5,1.5,3),(15,1,.8,1)],'structural_dark')
    F.hull('Wide recessed visor',[(7,3.6,.7,4.4),(11,2.5,.7,3.5),(13,1.3,.4,2.3)],'enamel_teal')
    for s,label in [(-1,'L'),(1,'R')]:
        engine(s*8,-14,-1,3,label)
        arm=pivot('Anim_Jammer_'+label,(s*8,-2,3))
        F.cylinder('Large deployment bearing',(0,0,0),2,2,'edge_steel',arm)
        F.hull('Tapered deployment outrigger',[(-2,6,1,0),(2,6,1,0)],'structural_dark',arm).location.x=s*6
        for n,y in enumerate([-4,0,4]):
            vane=pivot('Anim_Vane_'+label+'_'+str(n),(s*13,y,1),arm)
            F.box('Framed interference plate',(0,0,0),(6,3.2,1.4),'safety_orange',vane)
            F.box('Recessed interference core',(0,0,.8),(4.5,2,.25),'enamel_teal',vane)
            F.box('Emitter protective ridge',(s*2.7,0,.9),(.4,3.2,.8),'structural_dark',vane)
        for y in [-10,-7,-4]:F.box('Armored cooling grille',(s*5,y,4.6),(5,1,.8),'structural_dark')
    F.cylinder('Interference generator',(0,-6,5),3.2,3,'edge_steel')
    F.cylinder('Recessed generator lens',(0,-6,6.6),2.5,.25,'enamel_teal')
    gun=pivot('Anim_Gun',(0,7,-2))
    F.hull('Ventral pulse armor',[(-3,3.5,1.8,0),(3,3,1.3,0)],'structural_dark',gun)
    weapon(gun,-1.8,1,0,.9,'L');weapon(gun,1.8,1,0,.9,'R')
    F.box('Cargo recovery rail',(0,-2,-5),(8,17,1.2),'structural_dark')

def mount():
    F.cylinder('Low dorsal hardpoint',(0,0,0),2.2,.55,'structural_dark')
    joint=pivot('Anim_Yaw',(0,0,.4));F.cylinder('Traverse bearing',(0,0,0),1.9,.45,'edge_steel',joint)
    for s in [-1,1]:
        F.box('Trunnion armor',(s*1.6,0,.7),(.65,2.6,1.4),'enamel_cream',joint)
        F.cylinder('Elevation bearing',(s*1.8,0,.8),.5,.3,'edge_steel',joint).rotation_euler.y=math.pi/2
    cradle=pivot('Anim_Elevation',(0,0,.9),joint)
    F.hull('Sloped breech housing',[(-1.8,1.3,.7,0),(1,1.3,.8,0),(2,.8,.5,0)],'enamel_cream',cradle)
    weapon(cradle,-.75,1,.2,.28,'L');weapon(cradle,.75,1,.2,.28,'R')
    F.box('Rear service hatch',(0,-1.85,.1),(1.8,.2,.6),'safety_orange',cradle)
    for x in [-.7,0,.7]:F.box('Breech cooling slots',(x,-.7,.85),(.28,1.1,.1),'structural_dark',cradle)

if __name__ == '__main__':
    records=[]
    for name,build,framing in [('pirate_raider',raider,58),('pirate_interdictor',interdictor,69),('expedition_pulse_mount',mount,12)]:
        for distant in ([False,True] if name!='expedition_pulse_mount' else [False]):
            bpy.ops.wm.read_factory_settings(use_empty=True);F.LOD=distant;build()
            def frame(scene):scene.camera.data.ortho_scale=framing
            bpy.app.handlers.render_pre.append(frame)
            row=F.export(name+('_lod1' if distant else ''));row['revision']=2;row['motion']='Host-driven mechanical pivots; no baked skeletal clip'
            records.append(row);bpy.app.handlers.render_pre.remove(frame)
            bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']));bpy.context.scene.camera.data.ortho_scale=framing
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/row['source']))
    (F.SRC/'pirate_craft.json').write_text(json.dumps(records,indent=2)+'\n')
