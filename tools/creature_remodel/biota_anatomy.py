"""Continuous animal anatomy for the large biota construction groups.

Body layout, appendage connections and functional organ lineage are separate inputs.
The old catalogue is read only; midpoint vertebrates and flyers use separate builders.
"""
import math
from mathutils import Vector as V
from build_batch import mouth, directions
from build_creature_remodel_r01 import limb

GROUND_KINDS={'spindle','lobopod','radial','tower','saddle','mantle','spiral','flat','chain','bilateral','crown','amphora','ribbon','branch'}

def chain(s,prefix,points,radii,parent='chest',role='spine',material=None):
    names=[]
    for i in range(len(points)-1):
        name=f'{prefix}{i}';s.bone(name,points[i],points[i+1],parent if i==0 else names[-1]);names.append(name);s.organs.append((name,role,i*.63))
    s.tube('Continuous tissue '+prefix,points,radii,soft=material is None,slot=material or 'skin',bone=names[0] if material else None)
    return names

def pad_legs(s,stations,height,width,radial=False):
    m=s.spec['morphology'];count=int(m['limb_count']);s.support_height=height
    for i in range(count):
        if radial:
            d=directions(count)[i];name,center=stations[i%len(stations)];hip=V(center)+d*.14
            knee=d*(width*.75)+V((0,0,height*.55));foot=d*width+V((0,0,.11));forward=d
        else:
            side=-1 if i%2==0 else 1;index=min(len(stations)-1,int((i//2)*len(stations)/max(1,count//2)))
            name,center=stations[index];center=V(center);hip=center+V((side*.17,0,-.04))
            knee=V((side*width*.80,center.y+(.16 if i<count/2 else -.19),height*.53));foot=V((side*width,center.y+(.09 if i<count/2 else -.12),.11));forward=V((side*.12,-1,0)).normalized()
        phase=(i%2)*.5+(i//2)*(.17 if count>4 else .5)
        limb(s,'leg'+str(i),hip,knee,foot,forward,.12 if count>=8 else .155,name,phase%1)
        # Readable knee capsule and extensor tendon retain the bend at running speed.
        s.oval('Articulated knee capsule '+str(i),knee,(.13,.14,.115),'shell','leg'+str(i)+'_lower')
        s.tube('Lower leg extensor tendon '+str(i),[knee+V((0,-.045,0)),knee.lerp(foot,.6)+V((0,-.035,0)),foot+V((0,-.03,.025))],[.048,.038,.026],'ventral','leg'+str(i)+'_lower')

def rosette_mouth(s,name,at,parent,direction=(0,-1,0),radius=.14,petals=4):
    at=V(at);d=V(direction).normalized();reference=V((0,0,1)) if abs(d.z)<.85 else V((1,0,0));side=d.cross(reference).normalized();up=side.cross(d).normalized()
    s.bone(name,at-d*.13,at+d*.12,parent)
    cavity=s.oval('Recessed muscular pharynx '+name,at,(radius,.032,radius),'mouth',name)
    cavity.rotation_mode='QUATERNION';cavity.rotation_quaternion=V((0,-1,0)).rotation_difference(d)
    for i in range(petals):
        angle=i*math.tau/petals;r=side*math.cos(angle)+up*math.sin(angle);p=at+r*radius*.90;tip=at+d*.13+r*radius*.24
        jaw=name+'_petal'+str(i);s.bone(jaw,p,tip,name);s.organs.append((jaw,'oral_petal',angle))
        s.tube('Radial gripping lip '+jaw,[p,p+d*.12+r*.03,tip],[radius*.34,radius*.25,.012],'ventral',jaw)
    s.muzzles[name]=at+d*.15
    return name

def sensory_surface(s,points,parent):
    count=int(s.spec['morphology']['eye_count'])
    for i,p in enumerate(points):
        p=V(p);s.oval('Protected sensory pit '+str(i),p,(.044,.026,.032),'dark',parent,seg=20,rings=12)
        if i<count:s.oval('Inset simple photoreceptor '+str(i),p+V((0,-.012,.008)),(.020,.015,.018),'iris',parent,seg=16,rings=10)
        s.tube('Living sensory rim '+str(i),[p+V((-.052,0,-.005)),p+V((0,.008,.045)),p+V((.052,0,-.005))],[.016,.027,.014],'ventral',parent,sides=10)

def face(s,at,parent='chest',long=False):
    at=V(at);kind=s.spec['construction'];m=s.spec['morphology'];count=int(m['eye_count'])
    s.bone('head',at+V((0,.23,.03)),at+V((0,-.23,0)),parent)
    if kind in ['radial','mantle','crown','amphora','branch']:
        # These organizations have distributed sensory/feeding organs, not a shared vertebrate face.
        if kind=='branch':
            tips=[(name,data) for name,data in s.bones.items() if name.startswith('radial_axis') and name.endswith('1')]
            for i,(name,data) in enumerate(tips):
                p=V(data['b']);d=(p-V(data['a'])).normalized();rosette_mouth(s,'terminal_oral'+str(i),p+d*.075,name,d,.085,3)
                sensory_surface(s,[p+V((0,0,.10))],name)
        elif kind=='amphora':
            points=[data['b'] for name,data in s.bones.items() if name.startswith('crown_wall') and name.endswith('1')]
            center=sum(points,V())/len(points);center.z-=.09
            s.tube('Elastic ascending throat',[(0,0,at.z),center+V((0,0,-.20)),center],[.26,.19,.24],soft=True)
            rosette_mouth(s,'apical_oral',center,'head',(0,0,1),.25,6)
            sensory_surface(s,[V((math.cos(a)*.27,math.sin(a)*.27,center.z-.15)) for a in [0,math.pi/2,math.pi,math.pi*1.5]],'head')
        else:
            z=at.z-.10;center=V((0,0,z));s.oval('Central feeding diaphragm',center,(.28,.28,.15),'ventral','head')
            rosette_mouth(s,'ventral_oral',center-V((0,0,.13)),'head',(0,0,-1),.20,5 if kind=='crown' else (4 if kind=='radial' else 6))
            sensory_surface(s,[V((math.cos(a)*.42,math.sin(a)*.42,z+.35)) for a in [math.pi*.2,math.pi*.8,math.pi*1.3,math.pi*1.7]],'chest')
    elif kind in ['lobopod','chain']:
        s.oval('Retractile anterior collar',at,(.27,.24,.21),soft=True)
        for k in range(3):
            center=at+V((0,-.14-k*.09,0));radius=.22-k*.025
            points=[center+V((math.cos(a)*radius,0,math.sin(a)*radius*.78)) for a in [j*math.tau/16 for j in range(17)]]
            s.tube('Flexible circumoral fold '+str(k),points,[.029]*17,'ventral','head',steps=2,sides=12)
        rosette_mouth(s,'telescopic_oral',at+V((0,-.37,0)),'head',radius=.13,petals=3 if kind=='lobopod' else 6)
        sensory_surface(s,[at+V((side*.21,-.12,.11+k*.075)) for side in [-1,1] for k in range(2)],'head')
    elif kind in ['flat','ribbon']:
        s.oval('Broad sensory leading edge',at,(.41,.21,.12),soft=True)
        for side in [-1,1]:
            d=V((side*.42,-.8,0));p=at+V((side*.21,-.13,-.05));name=rosette_mouth(s,'lateral_filter'+str(side),p,'head',d,.09,3)
            s.membrane('Cephalic filter hood '+str(side),[at+V((side*.06,.09,.06)),at+V((side*.43,.02,.13)),at+V((side*.40,-.24,.02)),at+V((side*.11,-.22,.025))],'shell','head')
        sensory_surface(s,[at+V((side*.27,-.025,.135)) for side in [-1,1]],'head')
    elif kind=='spiral':
        s.tube('Asymmetric radular feeding hood',[at+V((.11,.20,.02)),at,at+V((-.09,-.27,-.02))],[.22,.20,.14],soft=True)
        rosette_mouth(s,'radula',at+V((-.09,-.28,-.02)),'head',radius=.115,petals=4)
        for side in [-1,1]:
            points=[at+V((side*.16,.02,.10)),at+V((side*.27,-.04,.38)),at+V((side*.31,-.11,.43))];names=chain(s,'ocular_stalk'+str(side),points,[.045,.035,.030],'head','sensor')
            sensory_surface(s,[points[-1]],names[-1])
    else:
        high=kind=='tower';long=long or kind in ['saddle','bilateral']
        width=.20 if high else (.23 if long else .27);length=.38 if long else (.25 if high else .30)
        s.oval('Continuous cranial vault',at,(width,length,.19 if high else .23),soft=True)
        snout=at+V((0,-length*.82,-.04));s.oval('Tapered upper maxilla',snout,(width*.73,.23 if long else .18,.105),'skin','head')
        jaw_at=at+V((0,-length*.35,-.105));end=snout+V((0,-.14,-.015));s.bone('oral',jaw_at,end,'head');s.organs.append(('oral','hinged_jaw',0))
        s.tube('Articulated muscular lower jaw',[jaw_at,(jaw_at+end)*.5+V((0,0,-.03)),end],[.13,.125,.075],'ventral','oral')
        s.oval('Protected mouth slit',snout+V((0,-.085,-.055)),(width*.59,.14,.023),'mouth','head');s.muzzles['oral']=end+V((0,-.07,0))
        for side in [-1,1]:
            for k in range(2):
                p=snout+V((side*width*.52,-.04-k*.10,-.065));s.tube('Short gripping denticle',[p,p+V((0,0,-.042))],[.020,.002],'keratin','head',sides=8,steps=2)
            s.tube('Protected breathing slit',[snout+V((side*width*.48,-.08,.066)),snout+V((side*width*.54,-.01,.076))],[.020,.014],'dark','head',sides=10)
        for i in range(count):
            side=-1 if i%2==0 else 1;layer=i//2
            p=at+V((side*width*.78,-.03+layer*.065,.09+layer*.05));s.eye('orbital'+str(i),p,side,.067 if high else .09,'head',slit=not high)
            if high:s.membrane('Angular ocular hood '+str(i),[p+V((0,-.12,-.01)),p+V((side*.025,.02,.16)),p+V((0,.12,.025))],'ventral','head')
        if count==0:sensory_surface(s,[at+V((side*width*.83,-.08,.08)) for side in [-1,1]],'head')
        if kind in ['saddle','bilateral']:
            for side in [-1,1]:
                for k in range(3):s.tube('Tactile maxillary whisker',[snout+V((side*.15,k*.05,0)),snout+V((side*(.29+k*.035),-.10+k*.05,.025))],[.018,.003],'keratin','head',sides=8)
    s.muzzle=next(iter(s.muzzles.values()))

def station_organs(s,stations):
    """Seven functioning organ lineages, each attached to its own real carrier bone."""
    m=s.spec['morphology'];system=s.spec['organ_system'];n=int(m['radial_count']);mode=int(m['mode'])
    for i in range(n):
        parent,base,d=stations[min(len(stations)-1,i*len(stations)//n)];base=V(base);d=V(d).normalized();side=V((-d.y,d.x,0));side=side.normalized() if side.length>.01 else V((1,0,0))
        name='organ'+str(i);length=.28+.055*(i%3)+.07*mode;tip=base+d*length+V((0,0,.12));s.bone(name,base,tip,parent)
        s.organs.append((name,'rib' if system in ['armor','gills'] else ('panel' if system=='sails' else 'sensor'),i*.7))
        if system=='armor':
            s.membrane('Overlapping curved scute '+name,[base-side*.17,base+d*.20-side*.22,tip+d*.11,base+d*.20+side*.22,base+side*.17],'shell',name)
            s.tube('Living armour root '+name,[base-side*.15,base+V((0,0,.10)),base+side*.15],[.04,.055,.04],'ventral',name)
        elif system=='gills':
            s.tube('Branchial support '+name,[base,(base+tip)*.5,tip],[.06,.046,.012],'ventral',name)
            for k in range(4+mode):
                p=base.lerp(tip,(k+1)/(5+mode));span=math.sin((k+1)/(5+mode)*math.pi)*.19
                for sign in [-1,1]:s.tube('Attached gill filament '+name+str(k)+str(sign),[p,p+side*span*sign-d*.025,p+side*span*sign-d*.085],[.026,.022,.006],'ventral',name,sides=10,steps=3)
        elif system=='mandibles':
            s.oval('Jaw adductor '+name,base,(.15,.14,.12),soft=True)
            for sign in [-1,1]:
                jaw=name+'jaw'+str(sign);p=base+side*.11*sign;s.bone(jaw,p,tip+side*.06*sign,name);s.jaws.append(jaw)
                s.tube('Jointed chitin jaw '+jaw,[p,tip+side*.15*sign,tip+d*.17+side*.025*sign],[.075,.075,.009],'keratin',jaw)
                for k in range(3):
                    p=base.lerp(tip,.4+k*.22)+side*.09*sign
                    s.tube('Opposed gripping denticle '+jaw+str(k),[p,p-side*.075*sign+d*.035],[.03,.003],'keratin',jaw,sides=8,steps=2)
        elif system=='antennal_fans':
            s.tube('Sensory stalk '+name,[base,base+d*.20+V((0,0,.22)),tip+V((0,0,.18))],[.055,.037,.019],'shell',name)
            for k in range(3+mode):
                angle=(k/max(1,2+mode)-.5)*1.6;end=tip+V((0,0,.20))+side*math.sin(angle)*.26+d*math.cos(angle)*.19
                s.tube('Separate fan ray '+name+str(k),[tip+V((0,0,.18)),end],[.024,.007],'ventral',name,sides=10)
                s.oval('Protected antenna sensor '+name+str(k),end,(.020,.022,.027),'dark',name,seg=16,rings=10)
        elif system=='siphons':
            bend=base+d*.18+V((0,0,.31));end=tip+d*.17+V((0,0,.23));names=chain(s,name+'conduit',[base,bend,end],[.105,.09,.12],name,'neck')
            mouth(s,name+'mouth',end,names[-1],.115,d+V((0,0,.15)))
        elif system=='sails':
            high=base+V((0,0,.48+.08*mode))+d*.15
            s.tube('Membrane load spar '+name,[base,high,tip+d*.17],[.055,.045,.018],'shell',name)
            s.membrane('Attached elastic flank membrane '+name,[base-side*.08,high,tip+d*.17,tip-side*.07,base-d*.16],'ventral',name)
        elif system=='tendrils':
            points=[base,tip,tip+d*.28+V((0,0,-.10))];names=chain(s,name+'tactile',points,[.085,.065,.041],name,'tail')
            for sign in [-1,1]:
                end=points[-1]+d*.16+side*.16*sign;branch=chain(s,name+'branch'+str(sign),[points[-1],end],[.038,.008],names[-1],'tail')
    # Every additional mouth has a live socket; the primary remains at the actual head.

def body(s):
    m=s.spec['morphology'];kind=s.spec['construction'];mode=int(m['mode']);n=int(m['radial_count']);w=float(m['width']);h=float(m['height'])
    s.bone('chest',(0,.14,.72),(0,-.22,.76));stations=[];organs=[]
    if kind in ['spindle','lobopod','chain','ribbon']:
        z={'spindle':1.02,'lobopod':.59,'chain':.61,'ribbon':.37}[kind]*h
        length=(1.55 if kind=='spindle' else 1.85)+.10*n
        branches=2 if mode==3 else (3 if mode==2 and kind in ['chain','ribbon'] else 1)
        count=3 if kind=='spindle' else n
        for branch in range(branches):
            x=(branch-(branches-1)/2)*(.46 if mode==3 else .52)
            points=[]
            for j in range(count+1):
                t=j/count;points.append(V((x+(.18*math.sin(t*math.tau) if mode in [1,4] else 0),length*(.5-t),z+(.13*math.sin(t*math.pi) if kind=='spindle' else .05*math.sin(t*math.tau)))))
            names=chain(s,'axis'+str(branch)+'_',points,[.34 if kind=='spindle' else (.20 if kind=='ribbon' else .26)]*(count+1))
            stations.extend((names[min(j,count-1)],points[j]) for j in range(count))
            for j in range(n):
                t=(j+.5)/n;part=min(count-1,int(t*count));p=points[part].lerp(points[part+1],t*count-part);d=V(((-1 if j%2==0 else 1)*.7,0,.6));organs.append((names[part],p+V((0,0,.22)),d))
            if kind=='lobopod':
                for j,p in enumerate(points[:-1]):s.oval('Muscular metameric chamber '+str(branch)+'_'+str(j),p,(.31,.25,.27),soft=True)
        head_at=points[-1]+V((0,-.20,.09 if kind=='spindle' else .01));face(s,head_at,names[-1],True)
        tail_start=V(stations[0][1]);chain(s,'tail',[tail_start,tail_start+V((0,.50,.10)),tail_start+V((.20 if mode%2 else 0,.95,-.08))],[.22,.12,.016],stations[0][0],'tail')
        pad_legs(s,stations,z,.61*w,False)
    elif kind in ['tower','saddle','bilateral']:
        z=.86*h;span=1.1+.075*n
        if kind=='tower':
            points=[V((0,0,z)),V((0,.12,z+.55)),V((0,-.18,z+1.05+.14*mode)),V((0,-.42,z+1.20+.14*mode))]
            names=chain(s,'vertical',points,[.35,.27,.20,.24]);face(s,points[-1],names[-1]);stations=[('chest',V((0,0,z)))]
            organs=[(names[min(2,i*3//n)],points[min(2,i*3//n)]+V((0,0,.15)),directions(n)[i]) for i in range(n)]
        else:
            arches=2 if kind=='bilateral' or mode in [2,3] else 1
            for side_index in range(arches):
                x=(side_index-(arches-1)/2)*.63*w
                points=[V((x,span*.5,z)),V((x,.20,z+.55+.12*mode)),V((x,-.30,z+.61+.1*mode)),V((x,-span*.5,z))]
                names=chain(s,'arch'+str(side_index),points,[.28,.24,.24,.31]);stations.extend([(names[0],points[0]),(names[-1],points[-1])])
                if kind=='bilateral':
                    s.oval('Suspended paired visceral sac '+str(side_index),(x,0,z+.25),(.36,.58,.40),soft=True)
                for j in range(n):
                    t=(j+.5)/n;part=min(2,int(t*3));p=points[part].lerp(points[part+1],t*3-part);organs.append((names[part],p+V((0,0,.20)),V((-1 if side_index==0 else 1,0,.3))))
            neck=[V((0,-span*.5,z)),V((0,-span*.5-.35,z+.24)),V((0,-span*.5-(.60+.30*mode),z-.05))]
            names=chain(s,'suspension_neck',neck,[.21,.16,.20],names[-1],'neck');face(s,neck[-1],names[-1])
        pad_legs(s,stations,z,.95*w,kind=='tower')
    elif kind in ['radial','flat','mantle','crown','amphora','branch','spiral']:
        z=(.52 if kind in ['radial','flat','mantle'] else .85)*h;stations=[('chest',V((0,0,z)))]
        if kind=='spiral':
            turns=1.1+.18*mode;points=[V((math.cos(i/n*math.tau*turns)*(.4+.035*i),math.sin(i/n*math.tau*turns)*(.4+.035*i),z+.055*i)) for i in range(n+1)]
            names=chain(s,'coiled_axis',points,[.24]*len(points));stations=[(names[i],points[i]) for i in range(n)]
            face(s,points[-1]+V((0,-.22,0)),names[-1]);organs=[(names[i],points[i]+V((0,0,.20)),V((points[i].x,points[i].y,.3))) for i in range(n)]
        elif kind in ['crown','amphora']:
            s.oval('Contractile central visceral sac',(0,0,z),(.42*w,.39*w,.40),soft=True)
            for i,d in enumerate(directions(n)):
                points=[d*.27+V((0,0,z-.17)),d*(.61*w if kind=='crown' else .51*w)+V((0,0,z+.45)),d*(.70*w if kind=='crown' else .28*w)+V((0,0,z+.85+.1*mode))]
                names=chain(s,'crown_wall'+str(i),points,[.12,.15,.10],role='rib');organs.append((names[-1],points[-1],d+V((0,0,.25))))
            face(s,V((0,-.32,z+.17)),'chest')
        else:
            radius=(1.0+.035*n)*w;wide=kind in ['flat','mantle'];s.oval('Continuous central mantle',(0,0,z),(.65*w,.72*w,.27 if wide else .31),soft=True)
            rays=n
            for i,d in enumerate(directions(rays)):
                points=[d*.24+V((0,0,z)),d*radius*.65+V((0,0,z+.05)),d*radius+V((0,0,z+(.25 if kind=='branch' else -.13)))]
                names=chain(s,'radial_axis'+str(i),points,[.24,.19,.10] if not wide else [.28,.24,.14],role='ray')
                if kind=='branch' and mode in [2,3,4]:
                    side=V((-d.y,d.x,0))
                    for sign in [-1,1]:chain(s,'terminal_branch'+str(i)+str(sign),[points[1],points[-1]+side*.30*sign],[.13,.05],names[0],'neck')
                if wide:
                    side=V((-d.y,d.x,0));s.membrane('Living locomotor skirt '+str(i),[points[0],points[1]+side*.35,points[-1],points[1]-side*.35],'ventral',names[0])
                organs.append((names[-1],points[-1]+V((0,0,.08)),d))
            face(s,V((0,-.69*w,z+.07)),'chest')
        pad_legs(s,stations,z,(1.1 if kind in ['radial','flat','mantle','branch'] else .92)*w,True)
    else:raise ValueError(kind)
    station_organs(s,organs)
    s.spec['authored_anatomy']='Continuous '+kind+' anatomy; '+s.spec['organ_system']+' lineage; independent load and organ chains'
