"""Fictional restored Mars, derived from our authored red relief, never Earth land data.
Blender --background --python tools/build_restored_mars.py
"""
from pathlib import Path
import sys, json, hashlib, math
import bpy
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_planets as P
S=P.S
DEST=ROOT/'docs/production/media/corporate-space'
DEST.mkdir(parents=True,exist_ok=True)
S.RENDER=DEST

def restored_surface(_kind,v):
    radius,color,_=P.solar_surface('mars',v)
    lon=np.arctan2(v[:,1],v[:,0]);lat=np.arcsin(np.clip(v[:,2],-1,1))
    # Northern basin and scattered lowland seas. Preserve the authored canyon/highlands.
    broad=S.noise(v,1.25);fine=S.noise(v,4.1)
    basin=lat-.48+.46*np.sin(lon*2+.7)+.18*np.sin(lon*5+.8)*np.cos(lat)+.12*broad+.03*fine
    gulf=np.exp(-(((lon-.65)/.46)**2+((lat+.05)/.38)**2))
    basin=np.maximum(basin,gulf*.8-.42)
    sea=(basin>0)&(np.abs(lat)<1.36)
    shore=(basin>-.045)&~sea&(np.abs(lat)<1.32)
    green=(basin>-.36-.18*broad)&(basin<=-.045)&(np.abs(lat)<1.25)
    water=S.mix(S.rgb('155574'),S.rgb('268fa1'),np.clip(.75-basin*1.1,0,1))
    color[sea]=water[sea];radius[sea]=1.001
    color[shore]=S.mix(color[shore],S.rgb('8f9b73'),.7)
    vegetation=S.mix(S.rgb('366853'),S.rgb('799566'),np.clip(.5+broad*.4+fine*.12,0,1))
    fertility=np.clip((basin+.36+.18*broad)*4,0,1)
    color[green]=S.mix(color[green],vegetation[green],fertility[green])
    wind=v.copy();wind[:,0]+=.09*np.sin(lat*8);wind[:,1]+=.07*np.cos(lon*3)
    cloud=S.noise(wind,2.8)+.16*np.sin(lon*5+lat*12)-.60
    cloud[np.abs(lat)>1.35]=-1
    return radius,np.clip(color,0,1),cloud

def main():
    S.surface=restored_surface
    records={}
    for lod in [0,1]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.world=bpy.data.worlds.new('Mars review')
        bpy.ops.object.empty_add();root=bpy.context.object;root.name='Solar_mars_restored'
        root.rotation_euler.y=math.radians(25.2)
        surface=S.body_mesh('earth',384 if lod==0 else 96,192 if lod==0 else 48,root)
        surface.data.materials[0].name='mars_restored_vertex_paint'
        geometry=list(bpy.context.scene.objects)
        triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in geometry if o.type=='MESH')
        if lod==0:
            S.setup_render('mars_restored');bpy.context.scene.unit_settings.system='METRIC'
            bpy.ops.wm.save_as_mainfile(filepath=str(S.SOURCE/'mars_restored.blend'))
        bpy.ops.object.select_all(action='DESELECT')
        for o in geometry:o.select_set(True)
        path=S.OUTPUT/('mars_restored'+('_lod1' if lod else '')+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
        records['far' if lod else 'near']={'triangles':triangles,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'model':'res://assets/models/solar-system/'+path.name}
        if lod==0:bpy.ops.render.render(write_still=True)
    record={'id':'solar_mars_restored','source':'art/blender/solar-system/mars_restored.blend','generator':'tools/build_restored_mars.py','interpretation':'Fictional future restoration over authored Mars relief; no observed future shoreline claim','lods':records}
    (S.SOURCE/'mars_restored.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
