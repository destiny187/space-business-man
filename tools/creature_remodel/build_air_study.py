"""Grounded folding, takeoff, cruise and landing for the approved four-wing glider."""
from pathlib import Path
import sys,json,hashlib,math
import bpy
from mathutils import Vector as V,Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools'),str(Path(__file__).parent)]
from refine_creature_motion import from_source,mesh_digest
from build_creature_studies import smooth,biota_rig
from build_host_combat import keyframe
import build_batch as pipeline
SRC=ROOT/'art/blender/creature_remodel/flight';OUT=ROOT/'우주-비즈니스/assets/models/creature_remodel/flight';MEDIA=ROOT/'docs/production/media/creature-remodel/flight'
for p in [SRC,OUT,MEDIA/'blender']:p.mkdir(parents=True,exist_ok=True)

def main():
    row=next(r for r in json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r01.json').read_text())['forms'] if r['id']=='veilglider')
    s=from_source(row);before=mesh_digest();rig=s.arm;scene=bpy.context.scene;scene.render.fps=30
    extra=['ground_idle_loop','flight_loop','takeoff','landing']
    for state,duration in [('ground_idle_loop',2.),('flight_loop',2.),('takeoff',5.),('landing',5.)]:
        action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action;scene.frame_start=1;scene.frame_end=round(duration*30)+1
        for frame in range(scene.frame_end):
            scene.frame_set(frame+1);t=frame/30;phase=t*math.tau
            blend=1. if state=='flight_loop' else (smooth(0,5,t) if state=='takeoff' else (1-smooth(0,5,t) if state=='landing' else 0.))
            for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
            s.local('chest',(.018*math.sin(phase)*blend,0,0));s.local('neck',(.025*math.sin(phase),0,0));s.local('head',(-.016*math.sin(phase),0,0))
            for name in s.wings:
                side=-1 if '-1' in name else 1;segment=int(name.rsplit('_',1)[1]);beat=math.sin((t+(31 if state=='landing' else 0))*math.tau*1.5-segment*.42)
                fold=[1.10,-.60,.45][segment];flight=(.12 if segment==0 else -.09)+beat*(.38 if segment==0 else .29)
                s.local(name,(0,side*.12*(1-blend),side*(fold*(1-blend)+flight*blend)))
            for i,name in enumerate(s.flex):s.local(name,(0,.025*math.sin(phase-i*.65),.07*math.sin(phase-i*.7)*(.3+.7*blend)))
            bpy.context.view_layer.update()
            for leg in s.legs:
                foot=V(leg['foot'])+V((0,.34,.48))*blend;s.solve_leg(leg,foot)
            keyframe(s,frame+1)
    assert before==mesh_digest()==row['approved_mesh_digest']
    rig.animation_data.action=bpy.data.actions['ground_idle_loop'];scene.frame_set(1);source=SRC/'veilglider.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
    result={**row,'source':str(source.relative_to(ROOT)),'status':'flight-clips-built-awaiting-render','air_motion':True,'clips':row['clips']+extra,'lods':{}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            rig.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Approved far budget','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            rig.data.pose_position='POSE'
        path=OUT/('veilglider_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        result['lods'][lod]={**row['lods'][lod],'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];pipeline.MEDIA=MEDIA;pipeline.source_render(s)
    (SRC/'veilglider.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'우주-비즈니스/data/creature_remodel_flight.json').write_text(json.dumps({'version':1,'forms':[result]},ensure_ascii=False,indent=2)+'\n');print('FLIGHT_CLIPS_BUILT veilglider',flush=True)
if __name__=='__main__':main()
