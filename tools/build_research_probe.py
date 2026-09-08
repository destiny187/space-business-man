"""A06 T2 field probe: open diagnostic head, exposed rails and removable shields.
Reuses the station authoring helpers and the common INK material/edge contract.
"""
from pathlib import Path
import bpy, math, sys, json
ROOT=Path(__file__).resolve().parents[1]
exec(compile((ROOT/'tools/build_crew_stations.py').read_text().split('\nstart()\n')[0],str(ROOT/'tools/build_crew_stations.py'),'exec'))
OUT=ROOT/'art/blender/equipment';GAME=ROOT/'우주-비즈니스/assets/models/equipment'
REVIEW=ROOT/'docs/production/media/research-a06';REVIEW.mkdir(parents=True,exist_ok=True)
start()
box('Receiver chassis',(0,-.12,.05),(.34,.58,.25),'dark',bevel=.065)
box('Removable teal cover',(0,-.22,.19),(.37,.38,.13),'teal',bevel=.055)
box('Grip',(0,-.20,-.19),(.16,.20,.37),'rubber',bevel=.05)
box('Grip heel',(0,-.20,-.36),(.21,.25,.07),'orange',bevel=.022)
box('Rear battery',(0,-.45,.035),(.29,.12,.20),'cream',bevel=.05)
box('Trigger guard',(0,.00,-.16),(.23,.24,.06),'steel',bevel=.025)
# An exposed floating head reads as test apparatus, distinct from the sealed Mk.2.
head=pivot('Anim_Collar_Probe',(0,.48,.08))
for y,rad,depth,role in [(.10,.19,.10,'cream'),(.37,.205,.075,'orange'),(.64,.235,.08,'steel')]:
 cyl('Open head collar',(0,y,.08),rad,depth,role,head,(math.pi/2,0,0))
for a in [0,120,240]:
 t=math.radians(a);x=.20*math.cos(t);z=.08+.20*math.sin(t)
 cyl('Exposed tie rod',(x,.40,z),.025,.55,'steel',head,(math.pi/2,0,0))
 cyl('Calibration bolt',(x,.72,z),.038,.04,'orange',head,(math.pi/2,0,0))
# Recessed sampling aperture and three sensor prongs, not a finished drill tip.
cyl('Sampling aperture',(0,.689,.08),.178,.025,'dark',head,(math.pi/2,0,0))
cyl('Optical core',(0,.710,.08),.069,.015,'light',head,(math.pi/2,0,0))
for x in [-.16,.16]:
 box('Probe jaw',(x,.78,.08),(.065,.22,.10),'teal',head,bevel=.02)
 box('Jaw contact',(x,.895,.08),(.065,.025,.075),'steel',head,bevel=.009)
shield=pivot('Anim_PrototypeShield',(.22,.27,.10))
box('Partial side shielding',(.22,.28,.10),(.09,.32,.23),'cream',shield,bevel=.04)
for y in [.19,.28,.37]:box('Shield vent',(.271,y,.10),(.016,.037,.13),'dark',shield,bevel=.006)
tube('External sensor cable',[(-.17,-.29,.10),(-.29,-.18,.19),(-.29,.10,.23),(-.20,.38,.17)],.023,'orange')
box('Measurement display',(0,-.13,.29),(.25,.23,.06),'dark',bevel=.023)
for i,h in enumerate([.05,.10,.07,.13]):box('Diagnostic bar',(-.075+i*.05,-.13+h*.15,.325),(.022,h,.01),'light',bevel=.003)
pivot('Socket_Emitter',(0,.9,.08))
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'miner_probe.blend'))
editable=sum(o.type=='MESH' for o in scene.objects);surfaces=ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(GAME/'miner_probe.glb'),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
from mathutils import Vector
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.18,.20,.22)
bpy.ops.object.camera_add(location=(1.7,2,1.0));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.20,.05))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.8;scene.camera=cam
for pos,energy in [((1,1,3),350),((-2,0,1),200)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=energy;o.data.size=3;o.rotation_euler=(Vector((0,.2,0))-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/'miner-probe-blender.png');bpy.ops.render.render(write_still=True)
(OUT/'research-probe-manifest.json').write_text(json.dumps({'id':'miner_probe','source':'art/blender/equipment/miner_probe.blend','output':'우주-비즈니스/assets/models/equipment/miner_probe.glb','generator':'tools/build_research_probe.py','blender':bpy.app.version_string,'material_preset':ink.PRESET['version'],'editable_objects':editable,'export_surfaces':surfaces,'front':'Blender +Y / Godot -Z','purpose':'T2 research prototype, open calibration head'},ensure_ascii=False,indent=2)+'\n')
