from pathlib import Path
import bpy,json,sys
ROOT=Path(__file__).resolve().parents[2];dest=ROOT/'docs/production/media/bestiary'
aberrant='--aberrant' in sys.argv
if aberrant:dest=dest/'aberrant'
expected=630 if aberrant else 900
samples=[21,291,561] if aberrant else [21,471,831]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;editor=scene.sequence_editor_create()
strip=editor.strips.new_movie('Verify encoded attacks',str(dest/('attacks.mp4' if aberrant else 'bestiary-attacks.mp4')),channel=1,frame_start=1)
assert strip.frame_final_duration==expected,strip.frame_final_duration
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.file_format='PNG'
for frame in samples:
 scene.frame_set(frame);scene.render.filepath=str(dest/f'video-frame-{frame}.png');bpy.ops.render.render(write_still=True)
(dest/'video-verification.json').write_text(json.dumps({'decoded_frames':strip.frame_final_duration,'fps':30,'duration_seconds':expected/30,'resolution':[1280,800],'decoded_samples':samples,'status':'pass'},indent=2)+'\n')
print('BESTIARY_VIDEO_VERIFIED',strip.frame_final_duration,flush=True)
