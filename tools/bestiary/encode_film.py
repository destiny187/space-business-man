from pathlib import Path
import bpy,sys
source,destination=sys.argv[sys.argv.index('--')+1:]
frames=sorted(Path(source).glob('frame-*.png'));assert frames and [p.name for p in frames]==[f"frame-{i:04d}.png" for i in range(len(frames))]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;editor=scene.sequence_editor_create()
strip=editor.strips.new_image('Attack presentation',str(frames[0]),channel=1,frame_start=1)
for p in frames[1:]:strip.elements.append(p.name)
strip.frame_final_duration=len(frames)
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.fps=30;scene.frame_start=1;scene.frame_end=len(frames)
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.media_type='VIDEO';scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264';scene.render.ffmpeg.constant_rate_factor='MEDIUM'
scene.render.filepath=str(Path(destination).resolve())
bpy.ops.render.render(animation=True)
print('BESTIARY_FILM_ENCODED',destination,flush=True)
