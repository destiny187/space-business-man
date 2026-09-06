"""Encode Godot's AVI capture with Blender's bundled video encoder.
Blender --background --python tools/encode_preview.py -- input.avi output.mp4
"""
from pathlib import Path
import sys
import bpy
source,destination=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
editor=scene.sequence_editor_create()
strip=editor.strips.new_movie('Gameplay',str(Path(source).resolve()),channel=1,frame_start=1)
try: editor.strips.new_sound('Game audio',str(Path(source).resolve()),channel=2,frame_start=1)
except RuntimeError: pass
scene.render.resolution_x=1280
scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.fps=30
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.frame_start=1
scene.frame_end=strip.frame_final_duration
scene.render.image_settings.media_type='VIDEO'
scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4'
scene.render.ffmpeg.codec='H264'
scene.render.ffmpeg.constant_rate_factor='MEDIUM'
scene.render.ffmpeg.audio_codec='AAC'
scene.render.filepath=str(Path(destination).resolve())
bpy.ops.render.render(animation=True)
print('PREVIEW_ENCODED',destination,flush=True)
