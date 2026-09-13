"""Blender-authored deployables and foredeck skill emitter, using the hull tooling."""
import bpy, json, math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_advanced_hulls as H
import ink_blender as ink

def build(kind):
    if kind=='combat_skill_emitter':
        H.box('Low profile deck base',(0,0,.12),(1.8,2.2,.25),'structural_dark')
        H.loft('Armored capacitor cradle',[(-1,.75,.45,.5),(.5,.7,.4,.5),(1,.48,.3,.5)])
        H.cylinder('Accelerator sleeve',(0,.45,.55),.38,1.6,'edge_steel')
        H.cylinder('Forward ion lens',(0,1.3,.55),.29,.12,'enamel_teal')
        for side in (-1,1):
            joint=H.empty('Anim_Capacitor_'+('L' if side<0 else 'R'),(side*.6,-.2,.5))
            H.box('Articulated capacitor vane',(side*.2,0,0),(.34,1.2,.22),'enamel_teal',.04,joint)
        H.empty('Socket_Skill_Muzzle',(0,1.4,.55))
    else:
        H.cylinder('Sealed electronic core',(0,0,0),.68,.8,'structural_dark','Z')
        H.cylinder('Ceramic cap',(0,0,.44),.63,.16,'enamel_cream','Z')
        H.cylinder('Status lens',(0,0,.55),.34,.08,'safety_orange' if kind=='combat_mine' else 'enamel_teal','Z')
        for i in range(4):
            angle=i*math.tau/4;arm=H.empty('Deployable arm '+str(i),(0,0,0));arm.rotation_euler.z=angle
            H.box('Radial protective arm',(1.0,0,0),(1.1,.28,.28),'edge_steel',.04,arm)
            if kind=='combat_decoy':
                H.box('Signal reflector',(1.42,0,.24),(.5,.88,.13),'enamel_teal',.045,arm)
                H.box('Protected antenna',(1.42,0,.55),(.06,.06,.6),'safety_orange',.01,arm)
            else:
                H.box('Proximity detector',(1.25,0,.13),(.38,.4,.34),'enamel_cream',.06,arm)
                H.box('Detector slit',(1.46,0,.13),(.035,.23,.12),'safety_orange',.01,arm)

rows=[]
for kind in ['combat_skill_emitter','combat_decoy','combat_mine']:
    bpy.ops.wm.read_factory_settings(use_empty=True);build(kind);H.lighting()
    scene=bpy.context.scene;scene.camera.data.ortho_scale=5
    scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=640;scene.render.resolution_y=520;scene.render.resolution_percentage=100
    source=H.SOURCE/(kind+'.blend');output=H.OUTPUT/(kind+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scene.objects:
        if obj.type in ('MESH','EMPTY'):obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True)
    scene.render.filepath=str(H.CAPTURE/(kind+'.png'));bpy.ops.render.render(write_still=True)
    rows.append({'id':kind,'source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),'style':'ink-v1'})
(H.SOURCE/'skill_devices.json').write_text(json.dumps(rows,indent=2)+'\n')
