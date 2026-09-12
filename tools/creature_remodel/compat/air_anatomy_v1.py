"""Load-bearing wing joints, protected flight organs, and buoyant animal membranes."""
import math
from mathutils import Vector as V
from biota_anatomy import chain,station_organs,rosette_mouth,sensory_surface
from build_creature_remodel_r01 import limb

def bird(s):
    f=s.spec['flight'];m=s.spec['morphology'];style=f['wing_style'];kind=s.spec['anatomical_type'];w=.29*m['width'];z=.92 if kind!='wader' else 1.40
    s.bone('chest',(0,.27,z),(0,-.25,z+.09));s.oval('Continuous aerodynamic rib cage',(0,0,z),(w,.52,.29),soft=True)
    s.oval('Flight muscle keel',(0,-.10,z-.10),(w*.80,.39,.26),soft=True)
    neck=[V((0,-.35,z+.07)),V((0,-.48,z+.28)),V((0,-.62,z+(.75 if kind=='wader' else .38)))]
    ns=chain(s,'flight_neck',neck,[.16,.115,.14],'chest','neck');at=neck[-1]+V((0,-.10,.02))
    s.bone('head',at+V((0,.1,0)),at+V((0,-.18,0)),ns[-1]);s.oval('Protected cranial capsule',at,(.23 if kind=='owl' else .18,.24,.22 if kind=='owl' else .18),soft=True)
    bill=.57 if kind=='wader' else (.25 if style=='scythe' else .20)
    tip=at+V((0,-bill-.15,-.055));s.tube('Curved upper feeding beak',[at+V((0,-.11,-.035)),at+V((0,-bill*.62-.13,-.01)),tip],[.125,.085,.008],'keratin','head',flat=.69)
    s.bone('oral',at+V((0,-.11,-.09)),tip,'head');s.organs.append(('oral','hinged_jaw',0))
    s.tube('Articulated lower beak',[at+V((0,-.12,-.09)),at+V((0,-bill*.64-.12,-.10)),tip+V((0,.025,-.016))],[.077,.058,.005],'ventral','oral',flat=.6)
    s.muzzles['oral']=tip;s.muzzle=tip
    for side in [-1,1]:
        p=at+V((side*(.175 if kind=='owl' else .145),-.04,.08));s.eye('Protected flight eye '+str(side),p,side,.10 if kind=='owl' else .073,'head',False)
        if kind=='owl':
            s.tube('Facial acoustic rim',[p+V((0,-.11,-.08)),p+V((side*.045,0,.14)),p+V((0,.12,-.05))],[.05,.065,.04],'ventral','head')
        else:s.membrane('Streamlined orbital hood',[p+V((0,-.07,.025)),p+V((0,.13,.09)),p+V((side*.025,.17,-.01))],'skin','head')
    s.wing_chains=[]
    for pair in range(int(f['wing_pairs'])):
        for side in [-1,1]:
            y=-.20+pair*.49;span=(1.38 if style in ['scythe','membrane'] else 1.12)*m['width'];root=V((side*w*.71,y,z+.10));elbow=V((side*span*.49,y-.10,z+.10));wrist=V((side*span*.84,y+.03,z+.11));end=V((side*span*1.22,y+.40,z+.04))
            prefix='wing'+str(pair)+'_'+str(side)+'_';names=chain(s,prefix,[root,elbow,wrist,end],[.11,.085,.05,.013],'chest','wing')
            s.wing_chains.append({'bones':names,'side':side,'pair':pair})
            s.membrane('Attached proximal flight web',[root,elbow,wrist,root+V((0,.49,0))],'skin')
            if style=='membrane':
                count=4
                for i in range(count):
                    finger='wingfinger'+str(pair)+'_'+str(side)+'_'+str(i);tip=wrist+V((side*(.28+i*.13),.16+i*.20,-.03));s.bone(finger,wrist,tip,names[-1]);s.organs.append((finger,'flight_digit',i*.4))
                    s.tube('Tensioned membrane finger '+finger,[wrist,tip],[.035,.012],'keratin',finger)
                    if i:s.membrane('Continuous interdigital flight membrane',[wrist,previous,tip,elbow+V((0,.2,0))],'ventral')
                    previous=tip
            else:
                count=int(f['primary_feathers'])+2
                for i in range(count):
                    fraction=i/(count-1);p=elbow.lerp(end,fraction);length=(.48 if style=='scythe' else .57)*(1-.37*fraction);name='primary'+str(pair)+'_'+str(side)+'_'+str(i)
                    tip=p+V((side*(.24 if style=='scythe' else .13),length,-.025));s.bone(name,p,tip,names[1] if fraction<.5 else names[2]);s.organs.append((name,'flight_digit',i*.4))
                    s.membrane('Overlapping pennaceous primary '+name,[p-V((side*.08,0,0)),p+V((side*.09,.07,.015)),tip+V((side*.025,-.03,0)),tip-V((side*.055,0,0))],'shell' if i%3==0 else 'ventral',name)
                    s.tube('Flexible feather rachis '+name,[p,tip],[.018,.003],'keratin',name,sides=8)
            for i in range(3):
                p=root.lerp(elbow,(i+.3)/3);s.membrane('Shoulder flight covert',[p,p+V((side*.17,.08,.035)),p+V((side*.14,.33,0)),p+V((0,.21,0))],'skin',names[0])
    for side in [-1,1]:
        hip=V((side*.18,.18,z-.17));knee=V((side*.22,.38,z*.5));foot=V((side*.22,.12,.10));name='landing'+str(side)
        limb(s,name,hip,knee,foot,(0,-1,0),.057 if kind=='wader' else .077,'chest',.5 if side<0 else 0)
        for i in [-1,0,1]:s.tube('Landing talon',[foot+V((i*.035,0,0)),foot+V((i*.09,-.19,0)),foot+V((i*.09,-.23,-.02))],[.036,.024,.003],'keratin',name+'_foot')
    tail=[V((0,.37,z)),V((0,.69,z-.03)),V((0,1.08,z-.04))];names=chain(s,'steering_tail',tail,[.16,.10,.025],'chest','tail')
    for i in range(5 if style=='fan' else 3):
        x=(i-(2 if style=='fan' else 1))*.16;p=tail[-2]
        s.membrane('Spread steering rectrix',[p+V((x*.3,0,0)),p+V((x*.6,.35,.02)),p+V((x,.80,0)),p+V((x+.08,.70,0))],'shell',names[-1])
    # Small lineage organs sit on the keel, leaving the flight surface continuous.
    station_organs(s,[('chest',V((side*w*.65,.08,z-.10)),V((side*.7,.15,-.3))) for side in [-1,1]])
    s.support_height=z

def floater(s):
    k=s.spec['construction'];m=s.spec['morphology'];mode=int(m['mode']);n=int(m['radial_count']);z=1.13;w=.62*m['width']
    s.bone('chest',(0,0,z-.18),(0,0,z+.2));s.bone('head',(0,-.08,z-.1),(0,-.28,z-.14),'chest')
    s.oval('Continuous pressure-supported visceral core',(0,0,z),(w*.7,w*.73,.37),soft=True)
    s.wing_chains=[];stations=[]
    if k in ['bilateral','amphora']:
        for side in [-1,1]:
            p=V((side*w*.70,0,z+.17));s.oval('Attached buoyancy chamber '+str(side),p,(w*.50,.72,.51 if k=='amphora' else .29),soft=True)
            points=[p+V((0,.48,0)),p+V((0,0,.37)),p+V((0,-.51,0))];chain(s,'pressure_keel'+str(side),points,[.055,.075,.04],'chest','rib','shell')
            stations.append(('chest',p+V((0,.1,.28)),V((side*.7,0,.4))))
    elif k=='crown':
        for i in range(4+mode):
            a=i*math.tau/(4+mode);d=V((math.cos(a),math.sin(a),0));p=d*w*.60+V((0,0,z));tip=d*w*1.1+V((0,0,z+.48));names=chain(s,'coronal_lobe'+str(i),[p,tip,tip+V((0,0,.18))],[.18,.16,.045],'chest','rib');stations.append((names[-1],tip,d))
    else:
        rays=3+mode if k=='branch' else (6 if k=='radial' else (6+mode%3 if k=='mantle' else 4))
        for i in range(rays):
            a=i*math.tau/rays;d=V((math.cos(a),math.sin(a),0));points=[d*w*.40+V((0,0,z)),d*w*1.1+V((0,0,z+.06)),d*w*(1.8 if k=='branch' else 1.45)+V((0,0,z-.04))]
            names=chain(s,'buoyant_ray'+str(i),points,[.22,.18,.055],'chest','ray');stations.append((names[-1],points[-1],d))
            if k in ['flat','mantle']:
                tangent=V((-d.y,d.x,0));s.membrane('Attached undulating swimming skirt',[points[0]-tangent*.25,points[1]-tangent*.40,points[2],points[1]+tangent*.40,points[0]+tangent*.25],'ventral',names[0])
                if k=='mantle':
                    next_angle=(i+1)*math.tau/rays;neighbor=V((math.cos(next_angle),math.sin(next_angle),0))*w*1.10+V((0,0,z+.06))
                    s.membrane('Continuous bell mantle between radial ribs',[points[0],points[1],points[2]+V((0,0,-.18)),neighbor+V((0,0,-.12))],'skin')
    rosette_mouth(s,'ventral_oral',(0,-.14,z-.36),'head',(0,0,-1),.17,5);s.muzzle=s.muzzles['ventral_oral']
    for i in range(3+mode):
        a=i*math.tau/(3+mode);d=V((math.cos(a),math.sin(a),0));p=d*.28+V((0,0,z-.12));chain(s,'trailing_feeler'+str(i),[p,p+d*.17+V((0,0,-.32)),p+d*.28+V((0,.12,-.54))],[.045,.030,.008],'chest','tail')
    sensory_surface(s,[V((math.cos(a)*w*.48,math.sin(a)*w*.48,z+.34)) for a in [0,math.pi*.5,math.pi,math.pi*1.5]],'chest')
    station_organs(s,stations);s.support_height=.4

def body(s):
    if s.spec['air_motion']:bird(s)
    else:floater(s)
    s.spec['authored_anatomy']={'type':s.spec['anatomical_type'],'medium':s.spec['locomotion_medium'],'wing_chains':len(s.wing_chains),'ground_supports':len(s.legs),'organs':len(s.organs)}
