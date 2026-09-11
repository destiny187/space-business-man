"""Blender sources, GLBs and Cycles review for passive field weather shelters."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_ink_industry as kit
import ink_blender as ink
OUT = ROOT / 'docs/production/media/weather'
OUT.mkdir(parents=True, exist_ok=True)

def canopy():
    for x in [-2.65, 2.65]:
        for y in [-1.95, 1.95]:
            kit.box('Wide adjustable foot', (x,y,.12), (.65,.65,.24), 'dark', .06)
            kit.cyl('Anchoring bolt', (x+.19,y,.28), .055,.13,'steel')
            kit.rod('Telescoping lower column',(x,y,.24),(x,y,1.75),.115,'teal')
            kit.rod('Inner stainless column',(x,y,1.35),(x,y,3.05),.075,'steel')
            kit.ring('Orange locking collar',(x,y,1.65),.12,.035,'orange')
            kit.rod('Roof knee brace',(x,y,2.25),(x-math.copysign(.55,x),y,3.0),.055,'dark')
    for y in [-1.95,1.95]:
        kit.box('Continuous roof crossbeam',(0,y,3.02),(5.6,.16,.19),'dark',.04)
    for x in [-2.8,2.8]:
        kit.box('Rain gutter',(x,0,3.12),(.16,4.7,.18),'teal',.035)
    # A broad pitched metal roof, open sides and clear headroom; no solid central cylinder.
    for x in [-1.42,1.42]:
        panel=kit.box('Pitched acid resistant roof',(x,0,3.25),(2.91,4.65,.13),'cream',.04)
        panel.rotation_euler.y=math.copysign(.075,x)
        for y in [-1.5,0,1.5]:
            kit.rod('Roof stiffener',(math.copysign(.02,x),y,3.39),(math.copysign(2.8,x),y,3.18),.035,'teal')
    kit.box('Sealed ridge cap',(0,0,3.39),(.16,4.68,.13),'teal',.045)
    for x in [-2.8,2.8]:
        kit.pipe('Gutter outlet',[(x,1.9,3.15),(x,2.08,3.0),(x,2.08,.35)],.045,'dark')
    kit.box('Weather pictogram plate',(-1.8,-2.34,3.13),(.65,.035,.22),'teal',.025)
    for x in [-2.72,2.72]:
        kit.box('Corner visibility strip',(x,-2.34,3.16),(.16,.04,.16),'orange',.02)

def mast():
    kit.cyl('Cast grounding hub',(0,0,.25),.48,.45,'teal')
    for angle in [0,2*math.pi/3,4*math.pi/3]:
        x,y=math.cos(angle)*.78, math.sin(angle)*.78
        kit.rod('Splayed grounding leg',(0,0,.5),(x,y,.12),.10,'dark')
        kit.box('Ground contact plate',(x,y,.08),(.36,.36,.16),'steel',.04)
        kit.rod('Driven earth pin',(x,y,.08),(x,y,-.18),.04,'steel')
    kit.cyl('Insulated base housing',(0,0,.78),.29,.68,'cream')
    kit.rod('Telescoping mast',(0,0,.55),(0,0,4.5),.085,'steel')
    for z in [1.0,1.2,1.4]:kit.cyl('Ceramic insulator disc',(0,0,z),.22,.09,'cream')
    kit.ring('Maintenance collar',(0,0,1.72),.115,.04,'orange')
    kit.rod('Copper lightning conductor',(.13,0,.4),(.13,0,4.3),.028,'orange')
    kit.cyl('Collector crown',(0,0,4.4),.17,.18,'teal')
    for x,y in [(0,0),(.24,0),(-.24,0),(0,.24),(0,-.24)]:
        kit.rod('Rounded strike prong',(0,0,4.42),(x,y,5.0 if x==y==0 else 4.82),.045,'steel')
    kit.box('Inspection cover',(0,-.3,.73),(.32,.08,.34),'teal',.04)
    kit.cyl('Inspection indicator',(0,-.35,.79),.055,.03,'status',(math.pi/2,0,0))

records=[]
for key,build in [('field_canopy',canopy),('grounding_mast',mast)]:
    kit.reset();build();scene=bpy.context.scene;scene.unit_settings.system='METRIC'
    source=ROOT/'art/blender/buildings'/f'{key}.blend'
    model=ROOT/'우주-비즈니스/assets/models'/f'{key}.glb'
    source.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    editable=sum(o.type=='MESH' for o in scene.objects)
    ink.consolidate_static_surfaces()
    bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
    triangles=0
    for obj in scene.objects:
        if obj.type=='MESH':obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
    records.append({'id':key,'source':str(source.relative_to(ROOT)),'model':str(model.relative_to(ROOT)),'editable_meshes':editable,'triangles':triangles,'blender':bpy.app.version_string,'generator':'tools/build_weather_shelters.py','motion':'passive fixed structure','axis':'Blender Z up to Godot Y up'})
    kit.box('Review floor',(0,0,-.28),(100,100,.10),'cream',0)
    scene.world=bpy.data.worlds.new('Weather review');scene.world.color=(.15,.15,.15)
    center=Vector((0,0,1.75 if key=='field_canopy' else 2.5))
    bpy.ops.object.camera_add(location=(8,-11,8));cam=bpy.context.object
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=9 if key=='field_canopy' else 7.4;scene.camera=cam
    for pos,power in [((3,-5,9),1800),((-5,1,7),1200)]:
        bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object
        light.data.energy=power;light.data.shape='DISK';light.data.size=6
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/f'{key}-blender.png');bpy.ops.render.render(write_still=True)
(ROOT/'art/blender/buildings/weather.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
