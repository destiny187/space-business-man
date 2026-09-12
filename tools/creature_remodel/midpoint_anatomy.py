"""New fused tissues and functional skeletons for the named animal silhouettes.

Use the established body proportions, with new load paths, cranial construction,
segmented attack organs and species-lineage appendages. No old mesh is reused.
"""
import math
from mathutils import Vector as V
from biota_midpoint_art import PROFILES
from biota_anatomy import chain,station_organs,rosette_mouth,sensory_surface
from build_creature_remodel_r01 import limb

def head(s,at,size,muzzle,kind,parent):
    at=V(at);w,length,h=size;s.bone('head',at+V((0,length*.3,0)),at+V((0,-length,0)),parent)
    s.oval('Fused cranial vault',at,size,soft=True)
    bill=kind=='monotreme';flat=kind=='crocodilian'
    tip=at+V((0,-length*.65-muzzle*.70,-h*.22))
    snout=(.29,.35,.065) if bill else (w*.74,muzzle*.65+.08,h*(.42 if flat else .50))
    s.oval('Sensory bill' if bill else 'Muscular maxilla',tip,snout,'ventral','head')
    jaw_at=at+V((0,-length*.3,-h*.55));end=tip+V((0,-snout[1]*.8,-snout[2]*.5))
    s.bone('oral',jaw_at,end,'head');s.organs.append(('oral','hinged_jaw',0))
    s.tube('Articulated mandible',[jaw_at,(jaw_at+end)*.5+V((0,0,-.015)),end],[w*.55,w*.53,w*.30],'skin','oral')
    s.oval('Fine recessed mouth cleft',tip+V((0,-.01,-snout[2]*.75)),(snout[0]*.91,snout[1]*.91,.018),'mouth','head')
    s.muzzles['oral']=end+V((0,-.05,0));s.muzzle=s.muzzles['oral']
    for side in [-1,1]:
        p=at+V((side*w*.86,-length*.13,h*.30))
        size=.073 if kind in ['proboscid','cervid','giraffoid','camelid','rhinocerid'] else (.115 if kind in ['anuran','gekkonid','lagomorph'] else .09)
        s.eye('Ocular socket '+str(side),p,side,size,'head',slit=kind in ['felid','gekkonid','crocodilian','skink','bovid'])
        if kind in ['anuran','gekkonid']:
            s.oval('Raised protective orbital dome',p+V((0,.025,-.035)),(size*.8,size,size*.85),soft=True)
        nasal=tip+V((side*snout[0]*.44,-snout[1]*.77,snout[2]*.61))
        s.tube('Recessed respiratory slit',[nasal,nasal+V((0,.045,.01))],[.014,.008],'dark','head',sides=10)
        if kind in ['felid','canid','mustelid','lagomorph']:
            for k in range(3):s.tube('Tactile maxillary whisker',[tip+V((side*snout[0]*.7,k*.04,0)),tip+V((side*(snout[0]+.17+k*.02),-.04+k*.055,.01))],[.012,.002],'keratin','head',sides=8)
        if kind in ['canid','felid','crocodilian']:
            for k in range(3 if flat else 2):
                p=tip+V((side*snout[0]*.70,-snout[1]*.45+k*.12,-snout[2]*.72))
                s.tube('Occluding conical tooth',[p,p+V((0,0,-.070 if k==0 else -.04))],[.025,.002],'keratin','head',sides=10)
        if bill:
            for k in range(5):s.oval('Electroreceptor pore',tip+V((side*(.15+k*.016),-.12+k*.048,.06)),(.009,.019,.006),'dark','head',seg=12,rings=8)
    return at

def ears(s,at,kind):
    for side in [-1,1]:
        root=V(at)+V((side*.15,.06,.16));long=kind=='lagomorph';large=kind=='proboscid'
        name='pinna'+str(side);end=root+V((side*(.47 if large else .11),.08,.04 if large else (.66 if long else .26)))
        s.bone(name,root,end,'head');s.organs.append((name,'sensor',side))
        if large:points=[root,root+V((side*.38,.1,.34)),end+V((side*.13,.02,-.16)),root+V((side*.14,0,-.26))]
        else:points=[root+V((0,-.065,0)),end+V((side*.05,0,0)),root+V((side*.10,.12,0))]
        s.membrane('Living auditory pinna '+str(side),points,'ventral',name)
        s.tube('Rolled pinna rim '+str(side),points+[points[0]],[.024]*(len(points)+1),'skin',name)

def horn(s,at,side,kind):
    root=V(at)+V((side*.12,.02,.17))
    if kind=='bovid':points=[root+V((side*.35*math.sin(t*math.pi),.22*t,.32*math.sin(t*math.pi*.9))) for t in [i/16 for i in range(17)]]
    else:points=[root,root+V((side*.14,.04,.30)),root+V((side*.28,.13,.60)),root+V((side*.38,.19,.80))]
    s.tube('Load bearing cranial horn '+str(side),points,[.07*(1-i/(len(points)-1))+.009 for i in range(len(points))],'keratin','head')
    if kind=='cervid':
        for k,p in enumerate(points[1:-1]):
            tip=p+V((side*.18,-.24,.27));s.tube('Branching filter horn',[p,tip],[.040,.008],'keratin','head')
            s.membrane('Attached horn filter vane',[p,tip,tip+V((side*.10,.10,.14)),p+V((side*.05,.05,.1))],'ventral','head')

def quadruped(s):
    k=s.spec['construction'];m=s.spec['morphology'];torso,at,size,muzzle=PROFILES[k];w,length,depth,z=torso
    # Variation changes the actual joint stations and cranial profile, not only object scale.
    index=['armor','gills','mandibles','antennal_fans','siphons','sails','tendrils'].index(s.spec['organ_system'])
    length*=1+.025*(index-3);w*=1+.015*(3-index)
    points=[V((0,length*.69,z-.035)),V((0,0,z)),V((0,-length*.65,z+depth*.13))]
    s.bone('chest',points[0],points[1]);spine=chain(s,'axial',points,[depth*.72,depth*.88,depth*.63])
    s.oval('Fused rib cage',(0,0,z),(w,length,depth),soft=True)
    s.oval('Pelvic muscle mass',points[0],(w*.83,length*.43,depth*.82),soft=True)
    neck=[points[-1],points[-1].lerp(V(at),.46)+V((0,.03,.02)),V(at)]
    ns=chain(s,'cervical',neck,[min(w*.62,.27),min(w*.47,.23),min(w*.49,.25)],spine[-1],'neck')
    head(s,at,size,muzzle,k,ns[-1]);short=k in ['chelonian','crocodilian','gekkonid','skink','monotreme','anuran','armadillo','mustelid']
    for row,y in enumerate([-length*.59,length*.61]):
        for side in [-1,1]:
            if k=='macropod' and row==0:
                chain(s,'grasp'+str(side),[(side*.21,-.1,1.2),(side*.29,-.27,1.02),(side*.29,-.4,.98)],[.07,.05,.035],spine[-1],'sensor');continue
            hip=V((side*w*.76,y,z-.04));knee=V((side*(w+.20 if short else w*.84),y+(.20 if row else -.17),z*.51));foot=V((side*(w+.13 if short else w*.94),y+(.08 if row else -.06),.1))
            width=.17 if k in ['proboscid','rhinocerid','bovid'] else (.07 if k in ['giraffoid','cervid','skink'] else .11)
            if k in ['anuran','lagomorph'] and row:
                knee=V((side*(w+.16),length*.70,z*.60));foot=V((side*(w+.05),length*.12,.09));width=.18
            if k=='macropod':hip=V((side*.23,.18,.89));knee=V((side*.36,-.10,.51));foot=V((side*.32,.02,.10));width=.18
            name=('front' if row==0 else 'hind')+str(side);phase=.5 if (row==0)==(side<0) else 0
            if k in ['anuran','lagomorph','macropod']:phase=row*.5
            limb(s,name,hip,knee,foot,(0,-1,0),width,spine[-1] if row==0 else spine[0],phase)
            s.oval('Load bearing upper muscle '+name,hip.lerp(knee,.38),(width*1.6,width*1.65,(hip-knee).length*.29),soft=True)
            s.oval('Articulated knee capsule '+name,knee,(width*.86,)*3,'shell',name+'_lower')
            if k in ['cervid','giraffoid','camelid','bovid']:
                for digit in [-1,1]:s.oval('Divided weight hoof',foot+V((digit*.043,-.08,0)),(.043,.13,.075),'keratin',name+'_foot')
            if k in ['gekkonid','monotreme','anuran']:
                for digit in [-1,0,1]:
                    end=foot+V((digit*.14,-.26-.04*abs(digit),0));s.tube('Splayed load digit',[foot,end],[.04,.02],'ventral',name+'_foot')
                    if k=='gekkonid':s.oval('Adhesive lamella pad',end,(.075,.095,.025),'ventral',name+'_foot')
                if k!='gekkonid':s.membrane('Interdigital web',[foot+V((-.15,-.26,0)),foot,foot+V((.15,-.26,0))],'ventral',name+'_foot')
    s.support_height=z
    if k in ['cervid','proboscid','canid','felid','giraffoid','camelid','bovid','lagomorph','mustelid']:ears(s,at,k)
    if k in ['cervid','bovid']:
        for side in [-1,1]:horn(s,at,side,k)
    if k=='giraffoid':
        for side in [-1,1]:chain(s,'ossicone'+str(side),[V(at)+V((side*.12,.1,.16)),V(at)+V((side*.19,.1,.45))],[.07,.04],'head','sensor','keratin')
    if k=='proboscid':
        p=V(at);trunk=[p+V((0,-.36,-.13)),p+V((0,-.57,-.35)),p+V((0,-.69,-.66)),p+V((0,-.88,-.70))]
        names=chain(s,'prehensile_trunk',trunk,[.19,.14,.11,.095],'head','neck')
        rosette_mouth(s,'trunk_tip',trunk[-1],names[-1],radius=.085,petals=3)
        for side in [-1,1]:s.tube('Curved lateral tusk',[p+V((side*.28,-.28,-.18)),p+V((side*.40,-.57,-.30)),p+V((side*.44,-.84,-.12))],[.085,.065,.004],'keratin','head')
    if k=='rhinocerid':
        for i in range(2):s.tube('Nasal keratin horn',[V(at)+V((0,-.40+i*.22,.16)),V(at)+V((0,-.49+i*.25,.61-i*.19))],[.14-i*.025,.005],'keratin','head')
    if k=='camelid':
        for y in [-.24,.30]:s.oval('Integrated dorsal nutrient reservoir',(0,y,z+depth*.73),(.30,.34,.43),soft=True)
    if k in ['chelonian','armadillo','pangolin']:
        n=5 if k!='pangolin' else 8
        for j in range(n):
            y=-length*.80+j*length*1.60/(n-1);parent=spine[-1] if y<0 else spine[0]
            for side in [-1,1]:
                s.membrane('Overlapping articulated carapace',[(0,y-.14,z+depth*.98),(side*w*.77,y-.18,z+depth*.72),(side*w*1.05,y+.04,z),(side*w*.70,y+.19,z+depth*.66),(0,y+.13,z+depth*.96)],'shell',parent)
    tail_length=1.40 if k in ['crocodilian','skink','macropod','pangolin'] else (.78 if k in ['canid','felid','gekkonid','mustelid'] else .43)
    tail=[points[0],points[0]+V((0,.37,-.07)),points[0]+V((.09,tail_length*.70,-z*.55)),points[0]+V((.17,tail_length,-z*.62))]
    names=chain(s,'caudal',tail,[depth*.50,.14,.08,.012],spine[0],'tail')
    if k=='monotreme':s.oval('Broad muscular swimming tail',tail[2],(.30,.40,.07),'ventral',names[-1])
    # The seven organ systems change actual attachment branches and secondary animation.
    count=3;stations=[(spine[0] if i>1 else spine[-1],V((0,(i-1)*length*.53,z+depth*.88)),V(((-1 if i%2 else 1)*.4,0,.8))) for i in range(count)]
    station_organs(s,stations)

def arthropod(s):
    k=s.spec['construction'];m=s.spec['morphology'];wide=k in ['crab','hermit'];mantid=k=='mantid';z=.61 if wide else (.98 if mantid else .72);w=.55 if wide else .32
    s.bone('chest',(0,.27,z),(0,-.35,z));s.oval('Fused prosomal muscle',(0,0,z),(w,.49,.29),soft=True)
    abdomen=V((.22 if k=='hermit' else 0,.60,z+(.13 if k=='hermit' else -.02)))
    s.bone('abdomen',(0,.25,z),abdomen,'chest');s.organs.append(('abdomen','spine',.7));s.oval('Attached opisthosoma',abdomen,(.41,.56,.32),soft=True)
    if k=='beetle':
        for side in [-1,1]:
            name='elytron'+str(side);s.bone(name,(side*.06,.28,z+.23),(side*.11,.88,z+.22),'abdomen');s.organs.append((name,'panel',side))
            s.oval('Curved protective elytron',(side*.20,.60,z+.23),(.25,.52,.23),'shell',name)
    if k=='hermit':
        points=[abdomen+V((math.cos(t)*(.45-t*.028),math.sin(t)*(.45-t*.028),.16+t*.065)) for t in [i*math.pi*3/40 for i in range(41)]]
        s.tube('Continuous living spiral shield',points,[.16]*len(points),'shell','abdomen')
    if k=='mantid':
        ns=chain(s,'raised_thorax',[(0,-.22,z),(0,-.42,z+.48),(0,-.65,z+.66)],[.19,.13,.15],'chest','neck');at=V((0,-.68,z+.68));parent=ns[-1]
    else:at=V((0,-.54,z+.05));parent='chest'
    s.bone('head',at,at+V((0,-.16,0)),parent);s.oval('Connected sensory capsule',at,(.27,.23,.15),soft=True)
    rosette_mouth(s,'oral',at+V((0,-.23,-.06)),'head',radius=.105,petals=3);s.muzzle=s.muzzles['oral']
    for side in [-1,1]:
        p=at+V((side*.23,-.035,.085));s.eye('Compound receptor '+str(side),p,side,.11,'head',False)
        chain(s,'antenna'+str(side),[p,p+V((side*.12,-.24,.28)),p+V((side*.24,-.43,.32))],[.036,.020,.006],'head','sensor','keratin')
    count=4 if mantid else (6 if k=='beetle' else 8)
    for i in range(count):
        side=-1 if i%2==0 else 1;pair=i//2;y=-.27+pair*.59/max(1,count//2-1);hip=V((side*w*.79,y,z));knee=V((side*(w+.53),y+(.17 if pair else -.28),z*.72));foot=V((side*(w+.73),y+(.3 if pair else -.38),.10))
        limb(s,'leg'+str(i),hip,knee,foot,(side*.4,-.9,0),.085,'chest',(i%2)*.5+(i//2)*.20)
        for a,b,bone in [(hip,knee,'leg'+str(i)+'_upper'),(knee,foot,'leg'+str(i)+'_lower')]:s.tube('Articulated cuticle sheath',[a,a.lerp(b,.5),b],[.10,.085,.047],'shell',bone)
    s.support_height=z
    if k in ['scorpion','crab','hermit','mantid']:
        for side in [-1,1]:
            points=[at+V((side*.20,.10,-.1)),at+V((side*(.63 if not mantid else .38),-.32,-.20)),at+V((side*.62,-.82,-.07))]
            names=chain(s,'raptorial'+str(side),points,[.11,.12,.09],parent,'neck')
            if mantid:
                for j in range(6):
                    p=V(points[1]).lerp(V(points[2]),j/6);s.tube('Raptorial gripping tooth',[p,p+V((side*-.10,0,.055))],[.035,.002],'keratin',names[-1])
            else:
                base=points[-1];s.oval('Chela adductor',base,(.21,.27,.15),'shell',names[-1])
                for sign in [-1,1]:
                    jaw='pincer'+str(side)+'_'+str(sign);p=base+V((sign*.12,-.14,0));s.bone(jaw,p,p+V((sign*.02,-.30,0)),names[-1]);s.jaws.append(jaw)
                    s.tube('Opposed chela finger',[p,p+V((sign*.10,-.15,0)),p+V((sign*-.05,-.37,0))],[.075,.060,.006],'keratin',jaw)
    if k=='scorpion':
        pts=[abdomen,abdomen+V((0,.40,.10)),abdomen+V((0,.55,.51)),abdomen+V((0,.35,.87)),abdomen+V((0,-.10,.94))];names=chain(s,'stinger_axis',pts,[.16,.14,.12,.1,.065],'abdomen','neck')
        s.tube('Venom aculeus',[pts[-1],pts[-1]+V((0,-.27,-.15))],[.06,.002],'keratin',names[-1]);s.muzzles[names[-1]]=pts[-1]+V((0,-.27,-.15))
    station_organs(s,[('abdomen',abdomen+V((0,0,.28)),V((.3,0,.9))),('chest',V((0,.02,z+.26)),V((-.3,0,.9))),('chest',V((0,-.25,z+.24)),V((.2,0,.9)))])

def serpent(s):
    s.bone('chest',(0,.7,.21),(0,.4,.21));points=[]
    for i in range(17):
        t=i/16;points.append(V((.25*math.sin(t*math.tau*1.5),1.8-t*3.1,.20+.12*t)))
    names=chain(s,'undulating_axis',points,[.07+.14*math.sin(i/16*math.pi*.8) for i in range(17)],'chest','spine')
    head(s,points[-1]+V((0,-.16,.04)),(.24,.30,.15),.20,'skink',names[-1]);s.support_height=.25
    for i,p in enumerate(points[:-1]):
        s.membrane('Flexible ventral traction scale',[p+V((-.16,-.08,-.1)),p+V((.16,-.08,-.1)),p+V((.17,.07,-.1)),p+V((-.17,.07,-.1))],'ventral',names[i])
    station_organs(s,[(names[i],points[i]+V((0,0,.14)),V(((-1 if i%2 else 1)*.8,0,.4))) for i in [4,8,12]])

def body(s):
    k=s.spec['construction']
    if k in PROFILES:quadruped(s)
    elif k=='serpent':serpent(s)
    else:arthropod(s)
    s.spec['authored_anatomy']={'type':k,'support_limb_count':len(s.legs),'attachment_chains':len(s.organs),'jointed_oral_organs':len(s.muzzles)}
