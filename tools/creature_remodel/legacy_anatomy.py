"""Animal load paths for the retained sculptural families and earlier wildlife.

The open spaces, suspended viscera and unusual axes define these animals. Tissue,
feeding surfaces and articulated supports replace disconnected rigid sculptures.
"""
import math
from mathutils import Vector as V
from biota_anatomy import chain,rosette_mouth,sensory_surface,station_organs,pad_legs
from build_batch import directions,supports
from build_creature_remodel_r01 import limb
from midpoint_anatomy import quadruped,arthropod,head
from legacy_recipes import CLASSIC

def oral(s,name,at,parent='chest',direction=(0,-1,0),radius=.13,petals=4):
    rosette_mouth(s,name,at,parent,direction,radius,petals)
    sensory_surface(s,[V(at)+V((side*radius*.95,.04,radius*.65)) for side in [-1,1]],name)

def axis(s,name,points,radii,role='spine',parent='chest'):
    return chain(s,name,[V(p) for p in points],radii,parent,role)

def sensor(s,name,points,parent='chest',radius=.065):
    names=axis(s,name,points,[radius,radius*.65,radius*.42],'sensor',parent)
    sensory_surface(s,[V(points[-1])],names[-1]);return names

def panel(s,name,root,edge,parent,slot='shell'):
    root=V(root);edge=[V(p) for p in edge];s.bone(name,root,edge[len(edge)//2],parent);s.organs.append((name,'panel',len(s.organs)*.33))
    s.membrane('Attached muscular plate '+name,[root]+edge,slot,name)
    s.tube('Rolled plate margin '+name,edge,[.035]*len(edge),slot,name,sides=12)
    return name

def classic(s):
    k=s.spec['construction'];m=s.spec['morphology'];mode=m['mode'];w=m['width'];h=m['height'];lineage=m.get('lineage',0)
    mammals={'grazer':'bovid','stalker':'canid','burrower':'mustelid','lithic':'rhinocerid','runner':'macropod'}
    insects={'carapace':'crab','mantid':'mantid'}
    if k in mammals|insects:
        s.spec['construction']=s.spec.get('anatomical_type',(mammals|insects)[k])
        (quadruped if k in mammals else arthropod)(s);s.spec['construction']=k
        if k=='grazer':
            at=V(s.muzzles['oral'])
            for side in [-1,1]:
                pts=[at+V((side*.10,.09,0)),at+V((side*.19,-.12,-.02)),at+V((side*.12,-.27,.035))]
                names=axis(s,'prehensile_labium'+str(side),pts,[.075,.065,.035],'mouth','oral')
                s.oval('Soft split cropping pad',pts[-1],(.075,.10,.05),'ventral',names[-1])
        elif k=='lithic':
            for side in [-1,1]:
                hip=V((side*.39,0,.90));knee=V((side*.67,.06,.50));foot=V((side*.74,-.06,.1))
                if lineage:
                    fore=next(l for l in s.legs if l['name']=='front'+str(side));hind=next(l for l in s.legs if l['name']=='hind'+str(side))
                    hip=V(fore['hip']).lerp(V(hind['hip']),.5);foot=V(fore['foot']).lerp(V(hind['foot']),.5)+V((side*.13,0,0));knee=hip.lerp(foot,.5)+V((side*.12,0,0))
                limb(s,'median'+str(side),hip,knee,foot,(0,-1,0),.17,'chest',.25 if side<0 else .75)
            for j in range(4+mode%4):
                y=-.62+j*1.24/(3+mode%4);s.oval('Interlocking mineral dermal boss',(0,y,1.49 if not lineage else s.support_height+.34),(.35,.15,.18),'shell','chest')
        elif k=='burrower':
            for side in [-1,1]:
                foot=next(l for l in s.legs if l['name']=='front'+str(side))
                for j in [-1,0,1]:
                    p=V(foot['foot'])+V((j*.06,-.08,.04));s.tube('Excavating shovel claw',[p,p+V((j*.045,-.23,-.01))],[.06,.008],'keratin',foot['name']+'_foot')
        elif k=='runner':
            at=V((0,-.27,1.48)) if not lineage else (s.bones['head']['a']+s.bones['head']['b'])*.5+V((0,0,.15))
            sensor(s,'cranial_crest',[at,at+V((0,.04,.3)),at+V((0,.18,.44))],'head')
            for leg in s.legs:
                for j in [-1,0,1]:
                    p=V(leg['foot']);s.tube('Running traction digit',[p,p+V((j*.12,-.30,.01))],[.04,.005],'keratin',leg['name']+'_foot')
        elif k=='stalker':
            for side in [-1,1]:
                z=1.4 if not lineage else s.support_height+.16;sensor(s,'rear_audio'+str(side),[(side*.25,.15,z),(side*.33,.24,z+.25),(side*.42,.38,z+.32)])
        elif k=='mantid':
            for side in [-1,1]:
                for j in range(3):
                    p=V((side*.22,.30+j*.23,s.support_height+.22));panel(s,'abdominal_respiration'+str(side)+'_'+str(j),p,[p+V((side*.23,.08,.20)),p+V((side*.34,-.08,.07)),p+V((side*.12,-.14,0))],'abdomen','ventral')
                if lineage:
                    at=(s.bones['head']['a']+s.bones['head']['b'])*.5;pts=[at+V((side*.16,.10,-.08)),at+V((side*.49,-.15,.10)),at+V((side*.43,-.66,-.10))]
                    names=axis(s,'raptorial_secondary'+str(side),pts,[.10,.09,.065],'neck','head')
                    for j in range(4+lineage):
                        p=V(pts[1]).lerp(V(pts[2]),j/(4+lineage));s.tube('Opposing secondary gripping tooth',[p,p+V((-side*.09,0,.06))],[.025,.003],'keratin',names[-1])
        elif k=='carapace':
            for j in range(3 if lineage==4 else 2):
                p=V((0,.08+j*.27,s.support_height+.25));axis(s,'arched_carapace'+str(j),[p+V((-.5,0,-.14)),p+V((0,0,.35)),p+V((.5,0,-.14))],[.09,.13,.09],'rib')
            if lineage==2:
                # The shielded beetle lineage still needs real claws for its preserved attack.
                at=(s.bones['head']['a']+s.bones['head']['b'])*.5
                for side in [-1,1]:
                    pts=[at+V((side*.18,.05,-.08)),at+V((side*.44,-.26,-.03)),at+V((side*.37,-.59,.02))]
                    names=axis(s,'raptorial'+str(side),pts,[.10,.12,.08],'neck','head')
                    for sign in [-1,1]:
                        p=pts[-1]+V((sign*.065,0,0));jaw='terminal_chela'+str(side)+'_'+str(sign);s.bone(jaw,p,p+V((0,-.24,0)),names[-1]);s.jaws.append(jaw)
                        s.tube('Opposed terminal gripping claw',[p,p+V((sign*.10,-.12,.03)),p+V((-sign*.045,-.27,.02))],[.055,.046,.003],'keratin',jaw)
        return
    if k in ['coil','slug']:
        z=.28;length=2.6+.05*mode+.19*lineage;count=9+mode%6+lineage*2
        s.bone('chest',(0,.5,z),(0,.25,z));pts=[V(((.19+.045*lineage)*math.sin(i/count*math.tau*(1+.25*lineage)),length*(.5-i/count),z+.04*math.sin(i/count*math.pi))) for i in range(count+1)]
        names=axis(s,'peristaltic_axis',pts,[.09+.15*math.sin(i/count*math.pi*.85) for i in range(count+1)])
        for i,p in enumerate(pts[:-1]):
            s.oval('Ventral contractile traction pad',p-V((0,0,.16)),(.19,.16,.055),'ventral',names[i])
        if k=='coil':oral(s,'eversible_pharynx',pts[-1]+V((0,-.18,.02)),names[-1],radius=.16,petals=3+mode%3)
        else:
            oral(s,'grazing_radula',pts[-1]+V((0,-.12,-.07)),names[-1],radius=.11)
            for side in [-1,1]:sensor(s,'eyestalk'+str(side),[pts[-1]+V((side*.1,0,.08)),pts[-1]+V((side*.24,-.08,.31)),pts[-1]+V((side*.28,-.12,.40))],names[-1])
        s.support_height=.28;s.muzzle=next(iter(s.muzzles.values()));return
    # True swimming and membrane-wing families keep their medium and receive dedicated axes.
    z=.80;s.bone('chest',(0,.25,z),(0,-.35,z));pts=[(0,-.70,z),(0,-.2,z),(0,.5,z),(0,1.15,z),(0,1.70,z)]
    names=axis(s,'swimming_axis',pts,[.17,.34,.23,.10,.025]);s.oval('Continuous hydrodynamic trunk',(0,-.05,z),(.35*w,.70,.29),soft=True)
    oral(s,'oral',(0,-.91,z),names[0],radius=.16);s.bone('head',(0,-.45,z),(0,-.85,z),names[0])
    span=(1.42 if k in ['ray','winged'] else .69)*w
    for side in [-1,1]:
        pts=[V((side*.25,-.1,z)),V((side*span*.54,-.17-.07*lineage,z+.07)),V((side*span,.11-.13*lineage,z)),V((side*span*(.87-.08*lineage),.76+.06*lineage,z-.02))]
        fin=axis(s,'propulsive_fin'+str(side),pts,[.09,.06,.045,.01],'flight_wing' if k=='winged' else 'swim_fin')
        for j in range(5+mode%4):
            start=pts[0].lerp(pts[2],j/(5+mode%4));end=start+V((side*.09,.62*(1-j/(7+mode%4)),0));n='fin_ray'+str(side)+'_'+str(j)
            s.bone(n,start,end,fin[min(2,j*3//(5+mode%4))]);s.organs.append((n,'swim_ray',j*.4));s.tube('Flexible propulsive ray',[start,end],[.03,.007],'keratin',n)
        s.membrane('Continuous tensioned propulsive membrane',[pts[0],pts[1],pts[2],pts[3],V((side*.18,.49,z-.04))],'ventral')
        if lineage in [2,4]:
            back=[V((side*.2,.6,z)),V((side*span*.45,.9,z+.03)),V((side*span*.64,1.24,z))]
            names=axis(s,'posterior_propulsor'+str(side),back,[.07,.045,.015],'flight_wing' if k=='winged' else 'swim_fin')
            s.membrane('Separate posterior propulsion membrane',[back[0],back[1],back[2],V((side*.12,1.3,z))],'ventral')
    for side in [-1,1]:panel(s,'caudal_fluke'+str(side),(0,1.30,z),[(side*.35,1.58,z),(side*.22,1.89,z),(0,1.65,z)],names[-1],'ventral')
    if k=='winged':
        for side in [-1,1]:limb(s,'clasp'+str(side),(side*.17,.12,z-.1),(side*.25,.31,.42),(side*.28,.12,.1),(0,-1,0),.07,'chest',0 if side<0 else .5)
    s.support_height=z;s.muzzle=next(iter(s.muzzles.values()))

def bridges(s,k,m,z,w):
    n=int(m['radial_count']);mode=int(m['mode']);stations=[]
    if k=='twin_moons':
        pts=[(-.58,.32,z+.30),(-.18,.12,z+.11),(.25,-.08,z+.18),(.63,-.29,z+.62)]
        names=axis(s,'intervisceral_neck',pts,[.24,.14,.12,.26],'neck')
        for i in [0,3]:s.oval('Asymmetric attached visceral moon',pts[i],(.36,.40,.45 if i else .31),soft=True)
        stations=[(names[0],V(pts[0])-V((0,0,.3))),(names[-1],V(pts[-1])-V((0,0,.62)))];oral(s,'distal_oral',V(pts[-1])+V((0,-.34,0)),names[-1]);return stations
    arches=2 if k in ['double_vault','rib_sled','split_keel','blind_harp','lattice_beast'] else 1
    for i in range(arches):
        x=(i-(arches-1)/2)*.69*w;rise=.88 if k in ['blind_harp','double_vault','saddle_bridge'] else (.43 if k=='lattice_beast' else .12)
        pts=[V((x,.77,z)),V((x,.32,z+rise)),V((x,-.27,z+rise+.04*mode)),V((x,-.82,z))]
        names=axis(s,'dorsal_arch'+str(i),pts,[.16,.13,.13,.19]);stations.extend([(names[0],pts[0]),(names[-1],pts[-1])])
        if k in ['blind_harp','double_vault','saddle_bridge']:
            for j in range(n):
                a=pts[1].lerp(pts[2],(j+.5)/n);b=a-V((0,.02,.45+.10*math.sin(j)))
                neck=axis(s,'suspended_neural'+str(i)+'_'+str(j),[a,a.lerp(b,.6),b],[.055,.045,.06],'neck',names[1])
                s.oval('Suspended living receptor',b,(.09,.08,.11),'ventral',neck[-1])
                if k=='blind_harp':s.tube('Tensioned vibration cord',[b,pts[-1]],[.013,.012],'keratin',neck[-1])
        if k in ['lattice_beast','rib_sled']:
            for j in range(n+1):
                y=-.65+j*1.3/n;pts2=[(x,y,z),(0,y,z+.55),( -x,y,z)]
                ribs=axis(s,'articulated_crossrib'+str(i)+'_'+str(j),pts2,[.07,.11,.07],'rib',names[1]);s.oval('Rib joint organ',pts2[1],(.13,.10,.12),'ventral',ribs[-1])
    if k=='split_keel':
        for j in range(n):axis(s,'transverse_muscle'+str(j),[(-.35*w,-.55+j*1.1/n,z),(.02,-.55+j*1.1/n,z+.14),(.35*w,-.55+j*1.1/n,z)],[.09,.12,.09],'rib')
    oral(s,'hanging_oral',(0,-.88,z+.05),'chest',radius=.15);return stations

def coils(s,k,m,z,w):
    mode=int(m['mode']);n=int(m['radial_count']);stations=[];groups=2 if k in ['spiral_hinge','braid_crawler','offset_halo'] else 1
    if k=='braid_crawler':groups=2+mode%3
    if k=='offset_halo':groups=2+mode%2
    for j in range(groups):
        pts=[];count=10+n;phase=j*math.tau/groups
        for i in range(count+1):
            t=i/count;a=t*math.tau*(1.05+.07*(mode%4))+phase
            if k in ['gyre_tower']:p=V((math.cos(a)*.43*w,math.sin(a)*.43*w,z+t*(1.12+.08*mode)))
            elif k in ['corkscrew_spine','braid_crawler']:p=V((math.cos(a)*(.25 if groups>1 else .34)*w,1.05-2.1*t,z+math.sin(a)*.24))
            elif k=='spiral_hinge':p=V(((-1 if j==0 else 1)*(.25+t*.39)*w,math.cos(a)*t*.67,z+.48+math.sin(a)*t*.67))
            elif k=='offset_halo':p=V((math.cos(a)*.56*w,math.sin(a)*.22+j*.22-.11,z+.68+math.sin(a)*(.56 if j%2==0 else -.56)))
            else:p=V((math.cos(a)*(.19+t*.55)*w,-.08+math.sin(a)*(.19+t*.55),z+.05*t))
            pts.append(p)
        names=axis(s,'coiled_organ'+str(j),pts,[.13 if groups>1 else .17]*(count+1),'spine')
        stations.extend((names[i],pts[i]) for i in [0,count//3,2*count//3,count-1])
        oral(s,'coil_oral'+str(j),pts[-1],names[-1],(0,-1,0),.12,3+mode%3)
        for i in range(0,count,3):s.oval('Coil intersegmental shield',pts[i],(.16,.13,.17),'shell',names[i])
    return stations

def radial_bodies(s,k,m,z,w):
    mode=int(m['mode']);n=int(m['radial_count']);stations=[]
    s.oval('Connected central visceral pad',(0,0,z),(.42*w,.40*w,.23),soft=True)
    if k in ['funnel_stilt','tripod_bell','walking_calyx','umbrella_clutch']:
        layers=1+mode%3 if k=='umbrella_clutch' else 1
        for layer in range(layers):
            h=z+.38+layer*.34
            for i,d in enumerate(directions(n)):
                tangent=V((-d.y,d.x,0));p=d*.20+V((0,0,z));tip=d*(.70*w if k!='funnel_stilt' else .48*w)+V((0,0,h));mid=p.lerp(tip,.6)+V((0,0,.18))
                bones=axis(s,'oral_wall'+str(layer)+'_'+str(i),[p,mid,tip],[.10,.12,.07],'rib')
                edge=[mid-tangent*.26,tip-tangent*.22,tip+tangent*.22,mid+tangent*.26]
                panel(s,'oral_plate'+str(layer)+'_'+str(i),p,edge,bones[0],'ventral' if k=='tripod_bell' else 'shell')
                stations.append((bones[0],p));
            oral(s,'central_pharynx'+str(layer),(0,0,h-.10),'chest',(0,0,1),.20,5)
        if k=='umbrella_clutch':
            for i,d in enumerate(directions(n)):
                p=d*.28+V((0,0,z-.06));middle=p+d*.24+V((0,0,-.24));tip=middle-d*.12+V((0,0,-.18))
                names=axis(s,'subumbrellar_grasper'+str(i),[p,middle,tip],[.09,.07,.055],'neck')
                tangent=V((-d.y,d.x,0))
                for side in [-1,1]:
                    start=tip+tangent*.06*side;name='subumbrellar_finger'+str(i)+'_'+str(side);s.bone(name,start,start-d*.2,names[-1]);s.jaws.append(name)
                    s.tube('Opposing subumbrellar clasp',[start,start+tangent*.08*side-d*.12,start-d*.25],[.05,.035,.005],'keratin',name)
    else:
        for i,d in enumerate(directions(n)):
            p=d*.26+V((0,0,z));tip=d*(.83+.05*(mode%3))*w+V((0,0,z+.12));middle=p.lerp(tip,.55)
            if k in ['crown_anchor','crown_stalker']:middle.z+=.65;tip.z+=.53;tip-=d*.25
            if k=='eye_orchard':middle.z+=.55;tip.z+=.88+.08*(i%3)
            if k=='root_octant':middle.z+=.08;tip.z-=.18
            names=axis(s,'radial_trunk'+str(i),[p,middle,tip],[.16,.14,.08],'neck' if k in ['crown_stalker','eye_orchard'] else 'ray');stations.append((names[0],p))
            if k=='eye_orchard':
                s.oval('Protected distal compound chamber',tip,(.17,.16,.19),'ventral',names[-1]);sensory_surface(s,[tip+V((0,-.15,0))],names[-1])
                oral(s,'distal_jet'+str(i),tip+V((0,-.18,-.11)),names[-1],radius=.08)
            elif k=='cup_colony':
                oral(s,'independent_cup'+str(i),tip,names[-1],(0,-.3,1),.20,5)
                s.oval('Contractile feeding cup',tip-V((0,0,.14)),(.25,.25,.19),soft=True)
            elif k in ['crown_anchor','crown_stalker','umbrella_clutch']:
                for side in [-1,1]:
                    q=tip+V((side*.07,0,0));bone='opposed_hook'+str(i)+'_'+str(side);s.bone(bone,q,q-d*.23,names[-1]);s.jaws.append(bone)
                    s.tube('Paired inward gripping hook',[q,q-d*.12+V((side*.14,0,.14)),q-d*.29+V((0,0,.12))],[.07,.05,.003],'keratin',bone)
            elif k=='radial_mill':
                tangent=V((-d.y,d.x,0));panel(s,'paddle'+str(i),p,[middle-tangent*.23,tip-d*.05-tangent*.25,tip+d*.18,tip-d*.05+tangent*.25,middle+tangent*.23],names[0],'ventral');oral(s,'terminal_grip'+str(i),tip,names[-1],d,.12)
            elif k=='root_octant':
                for sign in [-1,1]:
                    end=tip+V((-d.y,d.x,0))*.22*sign+d*.19;bs=axis(s,'fork_tip'+str(i)+'_'+str(sign),[tip,tip.lerp(end,.5),end],[.09,.055,.03],'neck',names[-1]);oral(s,'terminal_oral'+str(i)+'_'+str(sign),end,bs[-1],d,.075)
    if not s.muzzles:oral(s,'ventral_oral',(0,-.20,z-.13),'chest',(0,-1,-.3),.16)
    return stations

def plates(s,k,m,z,w):
    mode=int(m['mode']);n=int(m['radial_count']);stations=[]
    if k in ['lantern_sail','window_sac']:
        s.oval('Living pressure chamber',(0,0,z+.25),(.41*w,.39,.59),soft=True)
        for side in [-1,1]:
            root=V((side*.12,.12,z));points=[root,root+V((side*.33,.06,.62)),root+V((side*.22,-.29,1.03))];names=axis(s,'pressure_frame'+str(side),points,[.09,.07,.05],'rib')
            panel(s,'pressure_window'+str(side),root,[points[1],points[2],root+V((side*.47,-.6,.38))],names[0],'ventral')
        oral(s,'pressure_nozzle',(0,-.35,z+.56),'chest',radius=.17);stations=[('chest',V((0,0,z)))]
    elif k in ['veil_antler','inverted_fan']:
        s.oval('Low neural mantle',(0,0,z),(.44*w,.57,.24),soft=True)
        for i in range(n):
            a=-1.05+i*2.10/max(1,n-1);root=V((-.24 if k=='inverted_fan' else 0,.14,z))
            tip=V(((.45+.55*math.cos(a))*w,math.sin(a)*.85,z+.15+math.cos(a)*.65)) if k=='inverted_fan' else V((math.sin(a)*.95*w,.31,z+.36+math.cos(a)*.77))
            names=axis(s,'sensory_spar'+str(i),[root,root.lerp(tip,.55),tip],[.07,.05,.012],'sensor')
            if i:panel(s,'sensory_veil'+str(i),root,[previous,tip],names[0],'ventral')
            previous=tip
        oral(s,'low_oral',(0,-.58,z),'chest');stations=[('chest',V((-.28 if k=='inverted_fan' else 0,0,z)))]
    elif k=='crescent_maw':
        pts=[V((math.cos(-2.25+i/12*4.5)*.75*w,math.sin(-2.25+i/12*4.5)*.83,z)) for i in range(13)];names=axis(s,'crescent_axis',pts,[.22]*13)
        for i in [0,-1]:oral(s,'opposed_oral'+str(i),pts[i],names[0] if i==0 else names[-1],(-.1,1 if i==0 else -1,0),.18)
        stations=[(names[i],pts[i]) for i in [0,4,8,11]]
    elif k=='asym_pincer':
        old=s.spec['construction'];s.spec['construction']='crab';arthropod(s);s.spec['construction']=old
        points=[(-.35,-.4,.70),(-.91,-.8,.85),(-1.25,-1.35,.75)];names=axis(s,'dominant_chela',points,[.19,.25,.20],'neck')
        for side in [-1,1]:
            p=V(points[-1])+V((side*.17,0,0));name='dominant_finger'+str(side);s.bone(name,p,p+V((0,-.48,0)),names[-1]);s.jaws.append(name);s.tube('Asymmetric gripping chela',[p,p+V((side*.17,-.27,.02)),p+V((-side*.05,-.60,0))],[.13,.10,.006],'keratin',name)
        return None
    else:
        count=n+2;pts=[V((.10*math.sin(i*.8),.9-i*1.8/count,z+(.18*math.sin(i/count*math.pi) if k=='knuckle_chain' else 0))) for i in range(count+1)]
        names=axis(s,'serial_visceral_axis',pts,[.18 if k=='ribbon_colony' else .23]*(count+1));stations=[(names[i],pts[i]) for i in range(count)]
        for i,p in enumerate(pts[:-1]):
            if k=='accordion_shell':
                ring=[p+V((math.cos(a)*.39*w,0,math.sin(a)*.30)) for a in [j*math.tau/24 for j in range(25)]]
                s.tube('Articulated concertina collar',ring,[.085]*len(ring),'shell',names[i],sides=14)
                s.tube('Flexible inter-collar fold',[q+V((0,-.10,0)) for q in ring],[.035]*len(ring),'ventral',names[i],sides=10)
            elif k=='petal_mantis':
                for side in [-1,1]:panel(s,'serial_plate'+str(i)+str(side),p,[p+V((side*.56*w,.16,.27)),p+V((side*.70*w,-.11,.1)),p+V((side*.22,-.23,0))],names[i],'shell')
            else:s.oval('Contractile serial visceral chamber',p,(.31,.22,.29),'ventral',names[i])
            if k in ['manymouth','ribbon_colony']:
                for side in [-1,1]:oral(s,'serial_oral'+str(i)+str(side),p+V((side*.24,-.07,.10)),names[i],(side*.7,-.4,.2),.08)
        if not s.muzzles:oral(s,'terminal_oral',pts[-1]+V((0,-.12,.03)),names[-1],radius=.14)
    return stations

def body(s):
    k=s.spec['construction'];m=s.spec['morphology'];w=float(m['width']);z=(1.16 if k=='funnel_stilt' else (.42 if k in ['rib_sled','ribbon_colony','root_octant'] else .72))*float(m['height'])
    if k in CLASSIC:classic(s)
    else:
        s.bone('chest',(0,.14,z),(0,-.24,z));stations=[]
        if k in ['double_vault','saddle_bridge','twin_moons','blind_harp','rib_sled','split_keel','lattice_beast']:stations=bridges(s,k,m,z,w)
        elif k in ['gyre_tower','spiral_maw','spiral_hinge','corkscrew_spine','braid_crawler','offset_halo']:stations=coils(s,k,m,z,w)
        elif k in ['walking_calyx','tripod_bell','funnel_stilt','cup_colony','crown_anchor','crown_stalker','umbrella_clutch','eye_orchard','radial_mill','root_octant']:stations=radial_bodies(s,k,m,z,w)
        else:stations=plates(s,k,m,z,w)
        if stations is not None and k!='lantern_sail':
            # Supports belong to the actual nearest body station; no distant floating leg roots.
            count=int(m['limb_count'])
            for i,d in enumerate(directions(count)):
                nominal=d*.45+V((0,0,z));parent,center=min(stations,key=lambda row:(V(row[1])-nominal).length);center=V(center)
                hip=center+d*.08;knee=hip+d*.33+V((0,0,-hip.z*.47));foot=V((hip.x+d.x*.49,hip.y+d.y*.49,.10))
                limb(s,'support'+str(i),hip,knee,foot,d,.105 if count>6 else .14,parent,(i*(count//2 if count%2 else 1)%count)/count)
                s.oval('Load bearing joint capsule',knee,(.12,.12,.105),'shell','support'+str(i)+'_lower')
            s.support_height=z
        elif k=='lantern_sail':s.support_height=z
        if 'head' not in s.bones:s.bone('head',(0,-.25,z),(0,-.45,z),'chest',False)
        # Small habitat organs complement, rather than replace, the family silhouette.
        # Coils already carry sensors on their articulated oral surfaces. A second
        # pair on the invisible chest would float inside the open moving coils.
        if k not in ['gyre_tower','spiral_maw','spiral_hinge','corkscrew_spine','braid_crawler','offset_halo']:
            sensory_surface(s,[V((side*.22,-.23,z+.18)) for side in [-1,1]],'chest')
    s.muzzle=next(iter(s.muzzles.values()))
    s.spec['authored_anatomy']={'family':k,'support_limbs':len(s.legs),'oral_organs':len(s.muzzles),'articulated_organs':len(s.organs)}
