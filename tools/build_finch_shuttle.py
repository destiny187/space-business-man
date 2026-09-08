"""FINCH single-seat intra-system freight craft. Blender source, GLB and source render."""
from pathlib import Path
# Reuse the established manufactured primitive and material helpers without building a rover.
exec((Path(__file__).parent/'build_scout_rover.py').read_text().split("root=empty('SCOUT_Rover'")[0])
OUT=ROOT/'art/blender/ships';OUT.mkdir(parents=True,exist_ok=True)
GAME=ROOT/'우주-비즈니스/assets/models/ships';GAME.mkdir(parents=True,exist_ok=True)
REVIEW=ROOT/'docs/production/media/finch';REVIEW.mkdir(parents=True,exist_ok=True)
root=empty('FINCH_LocalFreighter',(0,0,0))
box('Pressure keel',(0,0,1.06),(1.8,4.5,.58),dark,root,.22)
box('Cream pressure capsule',(0,.05,1.42),(1.92,3.82,.95),cream,root,.30)
box('Nose avionics',(0,1.86,1.28),(1.47,.91,.48),teal,root,.20)
box('Seat pedestal',(0,.35,1.82),(.68,.72,.25),dark,root,.08)
box('Pilot cushion',(0,.5,1.97),(.67,.72,.17),orange,root,.08)
box('Pilot backrest',(0,.02,2.23),(.69,.22,.7),dark,root,.10)
box('Pilot harness',(0,.16,2.21),(.44,.04,.50),teal,root,.04)
box('Dashboard',(0,1.03,2.12),(1.3,.32,.25),dark,root,.07)
box('Navigation screen',(0,.85,2.17),(.48,.03,.18),screen,root,.02)
for x in [-.38,.38]:cylinder('Yoke grip',(x,.69,2.02),(x,.69,2.22),.035,orange,root)
canopy=empty('Anim_Canopy',(0,-.42,2.3),root)
# Faceted wraparound glazing, broad readable frames.
verts=[(-.84,1.62,1.81),(.84,1.62,1.81),(.71,.88,2.85),(-.71,.88,2.85)]
panel('Front canopy',verts,glass,canopy)
for side in [-1,1]:
 x=side*.85
 panel('Side canopy',[(x,1.6,1.82),(x,-.48,1.82),(x*.83,-.40,2.81),(x*.83,.88,2.85)],glass,canopy)
 cylinder('Canopy sill',(x,-.5,1.83),(x,1.64,1.83),.05,teal,canopy)
 cylinder('Windshield pillar',(x,1.64,1.83),(x*.83,.88,2.85),.055,cream,canopy)
 cylinder('Canopy roof rail',(x*.83,.88,2.85),(x*.83,-.42,2.81),.05,cream,canopy)
box('Canopy roof',(0,-.04,2.84),(1.48,1.84,.12),cream,canopy,.08)
box('Canopy roof stripe',(0,-.04,2.913),(.22,1.8,.018),orange,canopy,.007)
box('Aft service bulkhead',(0,-.67,2.05),(1.76,.22,1.50),cream,root,.12)
for side in [-1,1]:
 x=side*1.62
 box('Cargo outriggers',(side*1.03,-.51,1.15),(.66,2.5,.24),steel,root,.08)
 box('Freight pod frame',(x,-.38,1.24),(1.03,2.94,.84),dark,root,.15)
 lid=empty('Anim_Cargo_'+str(side),(x,-1.65,1.62),root)
 box('Removable freight pod',(x,-.38,1.39),(.91,2.68,.85),teal,lid,.14)
 for y in [-1.35,.52]:
  box('Cargo strap',(x,y,1.84),(.93,.14,.045),cream,lid,.02)
  box('Cargo latch',(x+side*.46,y,1.44),(.05,.22,.3),orange,lid,.022)
 box('Pod serial plate',(x+side*.476,-.4,1.49),(.025,.65,.24),cream,lid,.02)
 cylinder('Engine cowling',(side*.79,-1.30,1.49),(side*.79,-2.47,1.49),.43,cream,root,40)
 cylinder('Dark exhaust shroud',(side*.79,-2.28,1.49),(side*.79,-2.64,1.49),.35,dark,root,40)
 cylinder('Engine throat',(side*.79,-2.61,1.49),(side*.79,-2.66,1.49),.235,screen,root,32)
 empty('Socket_Exhaust_'+str(side),(side*.79,-2.7,1.49),root)
 box('Aft stabilizer',(side*1.12,-1.96,2.06),(.13,.91,.72),teal,root,.08,rot=(0,side*.18,0))
 for y in [-1.35,1.15]:
  leg=empty('Anim_Leg_'+str(side)+'_'+str(y),(side*.92,y,1.0),root)
  cylinder('Landing strut',(side*.91,y,1.05),(side*1.12,y,.22),.07,steel,leg)
  cylinder('Strut guard',(side*.92,y,.88),(side*1.08,y,.38),.105,cream,leg)
  box('Landing shoe',(side*1.13,y,.12),(.48,.68,.19),dark,leg,.08)
 box('Navigation light',(side*.62,2.25,1.44),(.22,.055,.13),light,root,.03)
 cylinder('Boarding rail',(side*.88,.07,1.76),(side*.88,.64,1.76),.035,orange,root)
box('Boarding step',(-1.12,.86,.62),(.52,.58,.12),dark,root,.04)
empty('Socket_Pilot',(0,.45,1.97),root)
empty('Socket_Eye',(0,.60,2.65),root)
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'finch.blend'))
ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(GAME/'finch.glb'),export_format='GLB',export_cameras=False,export_lights=False)
# Source renderer inspection after source/export are safe on disk.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));bpy.context.object.data.materials.append(mat('Studio floor',(.13,.18,.20),0,.8))
bpy.ops.object.camera_add(location=(8,9,6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.25))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=8.4;bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(2,4,9));bpy.context.object.data.energy=1700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=7
bpy.context.scene.world.color=(.28,.28,.28)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/'blender-finch.png');bpy.ops.render.render(write_still=True)
print('FINCH_COMPLETE')
