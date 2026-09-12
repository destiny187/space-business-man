"""Grounded wing folding and flight driven by the existing seeded flight clock."""
import math,bpy
from mathutils import Vector as V,Matrix
from build_creature_studies import smooth
from refine_creature_motion import pulse

def animate(s):
    scene=bpy.context.scene;scene.render.fps=30;rig=s.arm;s.actions={};bird=s.spec['air_motion'];p=s.profile
    if bird:p['flight_reference_hz']=1.5
    states=[('idle_loop',2.),('move_loop',2.),('run_loop',1.2),('feed',2.4),('attack',2.8),('hurt',.8),('blocked',.9),('stop',.6),('turn_left',1.),('turn_right',1.),('down',1.2)]
    if bird:states += [('ground_idle_loop',2.),('flight_loop',2.),('takeoff',5.),('landing',5.)]
    for state,duration in states:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action;scene.frame_start=1;scene.frame_end=round(duration*30)+1
        for frame in range(scene.frame_end):
            scene.frame_set(frame+1);t=frame/30;phase=t/duration*math.tau
            for bone in rig.pose.bones:bone.rotation_mode='XYZ';bone.matrix_basis=Matrix.Identity(4)
            blend=1. if state=='flight_loop' else (smooth(0,5,t) if state=='takeoff' else (1-smooth(0,5,t) if state=='landing' else 0.))
            flight_clock=t
            if bird and state in ['takeoff','landing']:
                cfg=s.spec['flight'];transition=float(cfg['transition_seconds'])
                origin=float(cfg['rest_seconds']) if state=='takeoff' else float(cfg['cycle_seconds'])-transition
                flight_clock=(origin+t/5*transition)*float(cfg['flap_hz'])/p['flight_reference_hz']
            if bird and state in ['flight_loop','takeoff','landing']:phase=flight_clock/2*math.tau
            moving=state in ['move_loop','run_loop'];gait=p['run'] if state=='run_loop' else p;cycle=t/gait['period'] if moving else t/duration
            wind=pulse(t,0,.78,1.18) if state=='attack' else 0;strike=pulse(t,.88,1.08,1.36) if state=='attack' else 0
            down=smooth(0,1.1,t) if state=='down' else 0;hurt=pulse(t,0,.09,duration) if state in ['hurt','blocked'] else 0
            forward=t*gait['stride']/gait['stance']/gait['period'] if moving and bird else 0
            root_z=(0 if bird else .05*math.sin(phase))-.35*s.support_height*down
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,-forward,root_z)))
            s.local('chest',(.035*math.sin(phase)*blend-.10*hurt,0,.06*hurt+.08*down),scale=(1+.014*math.sin(phase),1+.014*math.sin(phase),1-.010*math.sin(phase)))
            for name,role,offset in s.organs:
                wave=math.sin(phase-offset)
                if role=='neck':s.local(name,(.10*wind-.22*strike+.017*wave,0,.013*wave))
                elif role=='tail':s.local(name,(.025*wave,0,.06*wave*(.3+.7*blend) if bird else .08*wave))
                elif role=='ray':s.local(name,(.045*wave,0,.06*wave))
                elif role=='rib':s.local(name,(.015*wave,0,0),scale=(1+.025*math.sin(phase),1,1+.04*wind))
                elif role=='panel':s.local(name,(0,.055*wave+.15*wind-.18*strike,0))
                elif role=='sensor':s.local(name,(.035*wave,0,.02*wave))
                elif role=='flight_digit':s.local(name,(.012*wave*blend,0,.016*wave*blend))
                elif role=='hinged_jaw':s.local(name,(-.22*wind+.06*strike-(.14*(.5+.5*math.sin(phase*2)) if state=='feed' else 0),0,0))
                elif role=='oral_petal':s.local(name,(math.sin(offset)*(.17*wind-.06*strike),0,math.cos(offset)*(.17*wind-.06*strike)))
            for chain in s.wing_chains:
                for segment,name in enumerate(chain['bones']):
                    side=chain['side']
                    # Three complete beats close the source loop. Runtime preserves each species' frequency.
                    beat=math.sin(flight_clock*math.tau*p['flight_reference_hz']-segment*.42-chain['pair']*.5)
                    folded=[1.13,-.73,.56][segment];flight=(.11 if segment==0 else -.08)+beat*(.40 if segment==0 else .28)
                    # Bone Y follows the wing span: local X flaps vertically, local Z folds aft.
                    s.local(name,(flight*blend,side*.12*(1-blend),side*folded*(1-blend)))
            s.local('head',(.06*wind-.15*strike+.01*math.sin(phase),0,0))
            for i,name in enumerate(s.jaws):s.local(name,(0,0,(-1 if i%2 else 1)*(.15*wind-.25*strike)))
            for name in s.lids:s.local(name,(0,0,.06*max(0,math.cos(phase)-.85)/.15))
            for leg in s.legs:
                foot=V(leg['foot']);fraction=(cycle+leg['phase'])%1
                if moving:
                    foot.y+=-forward+((-.5+fraction/gait['stance'])*gait['stride'] if fraction<gait['stance'] else (.5-smooth(0,1,(fraction-gait['stance'])/(1-gait['stance'])))*gait['stride'])
                    if fraction>=gait['stance']:foot.z+=math.sin((fraction-gait['stance'])/(1-gait['stance'])*math.pi)*.10
                foot+=V((0,.23,s.support_height*.57))*blend;s.solve_leg(leg,foot)
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root_z)))
            for bone in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:bone.keyframe_insert(data_path=prop,frame=frame+1,group=bone.name)
        s.actions[state]=action;rig.animation_data.action=None
    rig.animation_data.action=s.actions['ground_idle_loop' if bird else 'idle_loop'];scene.frame_set(1)
