"""Blender sources, game exports and shape review for field manufacturing."""
from pathlib import Path
import sys, math, json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
OUT=ROOT/'output/field-manufacturing';OUT.mkdir(parents=True,exist_ok=True)
def metalworks():
    k.box('Foundation',(0,0,.18),(4.6,3.8,.36),'dark',.12)
    k.box('Deck',(0,0,.42),(4.4,3.6,.16),'steel',.05)
    for x in [-2,2]:
        for y in [-1.5,1.5]:k.cyl('Anchored foot',(x,y,.18),.3,.4,'teal')
    k.cyl('Induction furnace shell',(-.85,.45,1.52),.94,2.1,'cream')
    for z in [.62,.85,1.4,1.95,2.5]:k.ring('Induction coil',(-.85,.45,z),.96,.055,'orange')
    k.cyl('Furnace collar',(-.85,.45,2.65),1.02,.22,'dark')
    k.cyl('Insulated charging lid',(-.85,.45,2.82),.85,.18,'teal')
    k.pipe('Fume extractor',[(-.85,.45,2.92),(-.85,1.28,3.15),(1.6,1.28,3.15),(1.6,1.28,3.7)],.2,'steel')
    k.cyl('Exhaust cover',(1.6,1.28,3.77),.37,.14,'cream')
    fan=k.pivot('Anim_Fan_Extractor',(1.6,1.28,3.9))
    for a in [0,math.pi/2,math.pi,math.pi*1.5]:
        o=k.box('Vent rotor',(1.6+math.cos(a)*.22,1.28+math.sin(a)*.22,3.9),(.4,.12,.08),'dark',.02,parent=fan);o.rotation_euler.z=a
    for x in [.4,1.85]:k.box('Press upright',(x,-.75,1.52),(.25,.35,2.1),'teal',.05)
    k.box('Hydraulic crosshead',(1.12,-.75,2.56),(1.9,.7,.4),'cream',.1)
    k.cyl('Press ram',(1.12,-.75,2.03),.19,.65,'steel')
    ram=k.pivot('Anim_Piston_Press',(1.12,-.75,1.62))
    k.box('Forging die',(1.12,-.75,1.62),(1.2,.65,.27),'dark',.06,parent=ram)
    k.box('Conveyor bed',(.7,-.78,.9),(2.8,1.2,.3),'teal',.06)
    for x in [-.55,-.2,.15,.5,.85,1.2,1.55,1.9]:k.cyl('Output roller',(x,-.78,1.1),.11,1.06,'steel',(math.pi/2,0,0))
    for x in [.2,.7,1.2]:k.box('Cooled billet',(x,-.78,1.27),(.36,.48,.17),'cream',.035)
    k.box('Operator console',(-1.7,-1.34,1.13),(.65,.4,.9),'teal',.08)
    k.box('Status display',(-1.7,-1.56,1.28),(.43,.035,.3),'dark',.025)
    for x in [-1.83,-1.62]:k.cyl('Safety switch',(x,-1.59,1.03),.055,.03,'orange',(math.pi/2,0,0))
def workbench():
    k.box('Tool cabinet',(-.65,0,.64),(.8,.85,1.25),'teal',.09)
    for z in [.3,.57,.84,1.1]:
        k.box('Drawer',(-.65,-.44,z),(.68,.045,.19),'cream',.025)
        k.rod('Drawer handle',(-.81,-.49,z),(-.49,-.49,z),.027,'steel')
    for y in [-.36,.36]:k.box('Bench leg',(.86,y,.64),(.12,.12,1.25),'dark',.025)
    k.box('Work surface',(0,0,1.32),(2.35,1.15,.2),'cream',.07)
    k.box('Cutting mat',(.15,-.15,1.44),(1.2,.7,.04),'teal',.025)
    for x in [-1,1]:k.rod('Rack upright',(x,.42,1.35),(x,.42,2.4),.055,'dark')
    k.box('Tool rack',(0,.43,2.03),(2.1,.12,.68),'teal',.04)
    for x in [-.75,-.35,.05,.45]:
        k.rod('Tool shank',(x,.33,1.89),(x,.33,2.15),.035,'steel')
        k.box('Tool grip',(x,.32,1.84),(.1,.09,.2),'orange',.03)
    k.box('Vise base',(.84,-.13,1.54),(.42,.42,.18),'dark',.04)
    for y in [-.28,.05]:k.box('Vise jaw',(.84,y,1.71),(.42,.1,.18),'steel',.025)
    k.rod('Vise screw',(.84,-.47,1.56),(.84,.25,1.56),.035,'steel')
    k.box('Tool body under assembly',(-.15,-.12,1.59),(.65,.26,.2),'teal',.055)
    k.cyl('Tool barrel',(.26,-.12,1.59),.085,.22,'steel',(0,math.pi/2,0))
    k.rod('Work light arch',(-1,.45,2.4),(1,.45,2.4),.06,'cream')
    k.box('Work light diffuser',(0,.32,2.38),(1.5,.1,.045),'status',.015)
records=[]
for key,build in [('metalworks',metalworks),('equipment_workbench',workbench)]:
    k.reset();build();scene=bpy.context.scene;scene.unit_settings.system='METRIC'
    source=ROOT/'art/blender/buildings'/f'{key}.blend';model=ROOT/'우주-비즈니스/assets/models'/f'{key}.glb'
    source.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    editable=sum(o.type=='MESH' for o in scene.objects)
    ink.consolidate_static_surfaces()
    bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
    records.append({'id':key,'source':str(source.relative_to(ROOT)),'model':str(model.relative_to(ROOT)),'editable_meshes':editable,'generator':'tools/build_field_manufacturing.py','axis':'Blender Z up / -Y front to Godot Y up / +Z front'})
    k.box('Review floor',(0,0,-.15),(100,100,.1),'cream',0)
    scene.world=bpy.data.worlds.new('Manufacturing review');scene.world.color=(.15,.15,.15)
    center=Vector((0,0,1.6 if key=='metalworks' else 1.2))
    bpy.ops.object.camera_add(location=(7,-10,7));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=7.3 if key=='metalworks' else 4.6;scene.camera=cam
    for pos,power in [((3,-5,9),1800),((-5,1,7),1200)]:
        bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=6;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/f'{key}-blender.png');bpy.ops.render.render(write_still=True)
(ROOT/'art/blender/buildings/field_manufacturing.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
