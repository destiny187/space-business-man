"""One Blender-authored deep strata gallery, metre scale, open approach and central aisle."""
from pathlib import Path
exec((Path(__file__).parent/'build_exploration_discoveries.py').read_text().split('def build(id):')[0])
OUT=ROOT/'art/blender/underground';GAME=ROOT/'우주-비즈니스/assets/models/underground'
REVIEW=ROOT/'docs/production/media/deep-strata'
for path in [OUT,GAME,REVIEW]:path.mkdir(parents=True,exist_ok=True)
random.seed('deep-strata-gallery-v1')
p=empty('Deep_Strata_Gallery',(0,0,0))
slate=mat('Deep slate',(.17,.21,.24),.05,.84)
band=mat('Mineral seam',(.43,.36,.25),.08,.77)
for side in [-1,1]:
 for i in range(12):
  height=.43+i*.77
  x=side*(7.5+.25*math.sin(i*.85));y=2+.18*math.sin(i*.6)
  rock('Layered pier',(x,y,height),(1.35+random.random()*.25,1.35,.48),band if i%4==1 else slate,p)
 for i in range(4):
  rock('Broken bedding',(side*(9+i*.3),3.5-i*.5,.23+i*.19),(1.5,1.4,.33),slate,p)
for i in range(9):
 x=-7.2+i*1.8
 rock('Eroded bridge',(x,2,9.5+math.sin(i*math.pi/8)*1.15),(1.2,1.5,.75),band if i%3==0 else slate,p)
# Offset slabs frame the room without covering the three mineable deposit sockets.
for i in range(7):
 rock('Rear bedding',(-7.8+i*2.6,8,.35),(1.65,1.1,.50),slate,p)
# Save editable source before joining static surfaces for the game.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'deep_strata.blend'))
ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(GAME/'deep_strata.glb'),export_format='GLB',export_apply=True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world.color=(.18,.18,.18)
bpy.ops.object.light_add(type='AREA',location=(3,-8,14));bpy.context.object.data.energy=2600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=12
bpy.ops.object.light_add(type='AREA',location=(-10,3,10));bpy.context.object.data.energy=1800;bpy.context.object.data.size=10
bpy.ops.object.camera_add(location=(19,-25,17));camera=bpy.context.object;camera.rotation_euler=(Vector((0,2,4.8))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=25;scene.camera=camera
scene.render.filepath=str(REVIEW/'blender.png');bpy.ops.render.render(write_still=True)
print('DEEP_STRATA_EXPORTED')
