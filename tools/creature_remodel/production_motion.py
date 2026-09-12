"""Anatomical clips with axial waves, load-bearing IK and organ-specific anticipation."""
import math
import bpy
from mathutils import Vector as V,Matrix
from build_creature_studies import smooth
from refine_creature_motion import pulse

def animate(s):
    p=s.profile;rig=s.arm;scene=bpy.context.scene;scene.render.fps=30;s.actions={}
    states=[('idle_loop',2),('move_loop',2),('run_loop',1.2),('feed',2.4),('attack',2.8),('hurt',.8),('blocked',.9),('stop',.6),('turn_left',1),('turn_right',1),('down',1.2)]
    for state,duration in states:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action
        scene.frame_start=1;count=round(duration*30);scene.frame_end=count+1
        for f in range(count+1):
            scene.frame_set(f+1);t=f/30;moving=state in ['move_loop','run_loop'];gait=p['run'] if state=='run_loop' else p
            cycle=t/gait['period'] if moving else t/duration;phase=cycle*math.tau
            for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
            forward=t*gait['stride']/gait['stance']/gait['period'] if moving else 0
            wind=pulse(t,0,.78,1.18) if state=='attack' else 0;strike=pulse(t,.88,1.08,1.36) if state=='attack' else 0
            hurt=pulse(t,0,.09,duration) if state in ['hurt','blocked'] else 0;down=smooth(0,1.1,t) if state=='down' else 0
            root_z=(.012*math.cos(phase*2) if moving else .006*math.sin(phase))-.035*wind-s.support_height*.38*down
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,-forward,root_z)))
            s.local('chest',(-.10*hurt,0,.09*hurt+.10*down),scale=(1+.006*math.sin(phase),1+.006*math.sin(phase),1-.006*math.sin(phase)))
            for name,role,offset in s.organs:
                wave=math.sin(phase-offset);amplitude=.027 if moving else .007
                if role=='spine':s.local(name,(0,0,amplitude*wave))
                elif role=='tail':s.local(name,(.018*wave,0,(.050 if moving else .020)*wave))
                elif role=='neck':s.local(name,(.10*wind-.16*strike+.015*wave,0,.012*wave))
                elif role=='mouth':s.local(name,(.08*wind-.07*strike,0,.025*wave if state=='feed' else 0))
                elif role=='panel':s.local(name,(0,.04*wave+.14*wind-.20*strike,0))
                elif role=='rib':s.local(name,(.015*wave,0,0),scale=(1+.04*wind,1+.04*wind,1))
                elif role=='ray':s.local(name,(0,.018*wave,.018*wind))
                elif role=='sensor':s.local(name,(.025*wave,0,.018*math.sin(phase-offset*.8)))
                elif role=='oral_petal':
                    open_amount=.16*wind-.08*strike+(.11*(.5+.5*math.sin(phase*2)) if state=='feed' else 0)
                    s.local(name,(math.sin(offset)*open_amount,0,math.cos(offset)*open_amount))
                elif role=='hinged_jaw':s.local(name,(-.18*wind+.06*strike-(.13*(.5+.5*math.sin(phase*2)) if state=='feed' else 0),0,0))
            if 'head' in s.bones:s.local('head',(.10*wind-.19*strike+(.07*math.sin(phase) if state=='feed' else .009*math.sin(phase)),0,.012*math.sin(phase)))
            for i,name in enumerate(s.jaws):s.local(name,(0,0,(-1 if i%2 else 1)*(.16*wind-.25*strike+(.13*(.5+.5*math.sin(phase*2-i)) if state=='feed' else .01))))
            for name in s.lids:s.local(name,(0,0,.06*max(0,math.cos(phase)-.85)/.15))
            for leg in s.legs:
                foot=V(leg['foot']);fraction=(cycle+leg['phase'])%1
                if moving:
                    foot.y+=-forward+((-.5+fraction/gait['stance'])*gait['stride'] if fraction<gait['stance'] else (.5-smooth(0,1,(fraction-gait['stance'])/(1-gait['stance'])))*gait['stride'])
                    if fraction>=gait['stance']:foot.z+=math.sin((fraction-gait['stance'])/(1-gait['stance'])*math.pi)*min(.14,s.support_height*.22)
                if state.startswith('turn_'):foot.z+=max(0,math.sin((t+leg['phase'])*math.tau))*.08
                s.solve_leg(leg,foot)
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root_z)))
            for b in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:b.keyframe_insert(data_path=prop,frame=f+1,group=b.name)
        s.actions[state]=action;rig.animation_data.action=None
    rig.animation_data.action=s.actions['idle_loop'];scene.frame_set(1)
