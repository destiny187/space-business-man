"""Readable animal anatomy, built as editable Blender tissues and joint chains.

These are 26 ground constructions, not a deformation of the previous body blobs.
The two flight constructions are authored beside the existing wing constructor.
"""
import math
import bpy
from mathutils import Vector
import biota_eyes

A=None
B=None

# Rib cage width/length/depth/height; cranium position and scale; muzzle length.
PROFILES={
 'cervid':((.34,.70,.35,1.05),(0,-.95,1.80),(.21,.27,.23),.34),
 'proboscid':((.66,.94,.65,1.23),(0,-1.02,1.48),(.43,.43,.48),.12),
 'canid':((.32,.72,.35,.83),(0,-.92,1.06),(.23,.30,.25),.40),
 'felid':((.35,.84,.33,.70),(0,-1.04,.88),(.28,.25,.24),.16),
 'chelonian':((.72,.88,.39,.53),(0,-1.03,.45),(.22,.29,.20),.12),
 'crocodilian':((.42,1.02,.22,.39),(0,-1.17,.42),(.34,.40,.16),.65),
 'giraffoid':((.38,.68,.37,1.49),(0,-.98,2.78),(.20,.29,.23),.33),
 'camelid':((.43,.80,.46,1.06),(0,-1.19,1.69),(.22,.28,.26),.25),
 'rhinocerid':((.66,.83,.55,.88),(0,-.94,.87),(.39,.42,.36),.27),
 'bovid':((.50,.76,.52,.95),(0,-.96,1.03),(.32,.36,.34),.27),
 'anuran':((.54,.59,.30,.40),(0,-.55,.52),(.48,.32,.21),.12),
 'monotreme':((.38,.72,.31,.43),(0,-.74,.49),(.26,.28,.20),.42),
 'pangolin':((.43,.78,.35,.56),(0,-.93,.48),(.23,.28,.19),.42),
 'armadillo':((.48,.67,.38,.47),(0,-.83,.39),(.22,.28,.18),.28),
 'gekkonid':((.31,.67,.21,.30),(0,-.80,.37),(.30,.31,.20),.13),
 'skink':((.26,.92,.19,.27),(0,-1.04,.29),(.22,.32,.16),.20),
 'macropod':((.34,.43,.59,.99),(0,-.49,1.82),(.19,.26,.23),.24),
 'lagomorph':((.39,.54,.36,.57),(0,-.63,.79),(.25,.25,.24),.15),
 'mustelid':((.25,.98,.26,.40),(0,-1.12,.45),(.22,.26,.20),.20),
}

def v(point):return Vector(point)
def gd(point):return [round(point[0],6),round(point[2],6),round(-point[1],6)]

def chain(row,label,points,radii,slot='main',parent=None,animate=True):
    """Nested, tapered tissue sections. Each bone carries its distal children."""
    owner=parent or B.BODY;origin=Vector((0,0,0));nodes=[]
    for i in range(len(points)-1):
        at=v(points[i]);delta=v(points[i+1])-at
        q=B.pivot('Anim_Flex_'+label+'_%02d'%i,at-origin,owner)
        A.sweep('Connected '+label+' segment',[(0,0,0),tuple(delta*.5),tuple(delta)],radii[i],slot,q,[.90,.83,.72],24)
        A.oval('Covered '+label+' articulation',(0,0,0),(radii[i]*1.06,)*3,slot,q)
        if animate:row.setdefault('anatomical_motion',{})[q.name]={'axis':'y' if label in ('Tail','Spine') else 'x','amplitude':.045 if label=='Tail' else .025,'phase':i*.7,'speed':1.3}
        owner=q;origin=at;nodes.append(q)
    return nodes

def limb(row,label,hip,knee,foot,width=.085,style='paw',phase=0.,stride=.12,lift=.065):
    """Hip-knee-ankle hierarchy with data for a two-segment ground-contact solver."""
    h=v(hip);k=v(knee);f=v(foot);upper=k-h;lower=f-k
    shoulder=B.pivot('Anim_GaitHip_'+label,h,B.BODY)
    A.oval('Muscular limb root',(0,0,0),(width*1.4,width*1.35,width*1.6),'main',shoulder)
    A.sweep('Tapering proximal limb',[(0,0,0),tuple(upper*.48),tuple(upper)],width,'main',shoulder,[1.3,1.05,.7],24)
    hinge=B.pivot('Anim_GaitKnee_'+label,upper,shoulder)
    A.oval('Protected knee joint',(0,0,0),(width*.87,)*3,'secondary',hinge)
    A.sweep('Distal weight bearing limb',[(0,0,0),tuple(lower*.52),tuple(lower)],width*.69,'main',hinge,[1,.75,.65],24)
    ankle=B.pivot('Anim_GaitAnkle_'+label,lower,hinge)
    if style=='hoof':
        for side in [-1,1]:A.oval('Divided keratin hoof',(side*width*.42,-.035,-.025),(width*.42,width*1.15,.07),'bone',ankle)
    elif style=='pad':
        for digit in [-1,0,1]:
            end=(digit*.15,-.18-abs(digit)*.025,-.01)
            A.curve('Spreading adhesive digit',[(0,0,0),end],.036,'secondary',ankle)
            A.oval('Broad lamellar toe pad',end,(.095,.11,.035),'accent',ankle)
    elif style=='web':
        for digit in [-1,0,1]:A.curve('Webbed load bearing digit',[(0,0,0),(digit*.11,-.18,-.01),(digit*.14,-.25,-.02)],.035,'bone',ankle)
        A.leaf('Thick interdigital web',[(0,.04,.005),(0,-.13,.015),(0,-.25,-.02)],.20,'secondary',ankle)
    elif style=='long':
        A.oval('Long springing metatarsus',(0,-.12,.02),(.10,.24,.075),'main',ankle)
        for digit in [-1,1]:A.curve('Paired impact claw',[(digit*.05,-.24,.02),(digit*.055,-.37,-.02)],.032,'bone',ankle)
    elif style=='point':
        A.curve('Curved tarsal hook',[(0,0,0),(0,-.07,.0),(0,-.12,-.035)],max(.018,width*.4),'bone',ankle)
    else:
        A.oval('Cushioned paw',(0,-.045,.005),(width*1.2,width*1.7,.07),'secondary',ankle)
        for digit in [-1,0,1]:A.curve('Blunt digging claw',[(digit*width*.65,-width,.025),(digit*width*.70,-width*2.15,-.035)],.025,'bone',ankle)
    row.setdefault('gait',{'version':1,'rate':2.4,'limbs':{}})['limbs'][label]={
        'hip':shoulder.name,'knee':hinge.name,'ankle':ankle.name,
        'upper':gd(upper),'lower':gd(lower),'phase':phase,'stride':stride,'lift':lift}
    return shoulder,hinge,ankle

def head(row,at,size,muzzle,kind):
    q=B.pivot('Anim_Head',at,B.BODY);w,length,h=size
    cranium=A.oval('Continuous cranial vault',(0,0,0),size,'main',q,sectors=64,rings=32)
    if kind=='monotreme':
        A.oval('Broad electroreceptive bill',(0,-length-.16,-.06),(.29,.36,.065),'secondary',q)
        for side in [-1,1]:
            for k in range(3):A.oval('Bill sensory pore',(side*(.12+k*.025),-length-.08-k*.075,.005),(.022,.035,.015),'eye',q)
    elif kind=='crocodilian':
        A.oval('Long flattened maxilla',(0,-length-muzzle*.36,-.03),(w*.79,muzzle,.085),'secondary',q)
    elif kind=='proboscid':
        A.oval('Fused muscular trunk root',(0,-length*.74,-h*.08),(w*.47,.20,h*.45),'main',q)
    else:
        A.oval('Tapering upper muzzle',(0,-length*.75-muzzle*.35,-h*.27),(w*.67,muzzle*.70+.05,h*.47),'secondary',q)
    jaw=B.pivot('Anim_Flex_Jaw_00',(0,-length*.45,-h*.50),q)
    A.oval('Articulated lower jaw',(0,-muzzle*.5,-.01),(w*.57,muzzle*.60+.07,h*.20),'main',jaw)
    row.setdefault('anatomical_motion',{})[jaw.name]={'axis':'x','amplitude':.065,'phase':0,'speed':2.0,'feeding':True}
    biota_eyes.vertebrate(A,row,q,size,kind,cranium)
    if kind in ('canid','felid','mustelid','lagomorph'):
        nose=(0,-length*.75-muzzle*.35-(muzzle*.70+.05)*.97,-h*.27+.014)
        biota_eyes.cap(A,'Embedded tactile rhinarium',nose,(0,-1,.12),w*.25,h*.16,.010,'dark',q,True)
        A.curve('Fine central philtrum',[(0,nose[1]+.005,nose[2]-.017),(0,nose[1]+.004,nose[2]-.065)],.004,'dark',q)
    elif kind!='proboscid':
        for side in [-1,1]:
            if kind=='crocodilian':
                nasal_center=Vector((0,-length-muzzle*.36,-.03));nasal_size=Vector((w*.79,muzzle,.085));direction=Vector((side*.30,-.82,.486)).normalized()
            elif kind=='monotreme':
                nasal_center=Vector((0,-length-.16,-.06));nasal_size=Vector((.29,.36,.065));direction=Vector((side*.4,-.70,.59)).normalized()
            else:
                nasal_center=Vector((0,-length*.75-muzzle*.35,-h*.27));nasal_size=Vector((w*.67,muzzle*.70+.05,h*.47));direction=Vector((side*.35,-.90,.25)).normalized()
            at=nasal_center+Vector(tuple(direction[i]*nasal_size[i] for i in range(3)))
            normal=Vector(tuple(direction[i]/nasal_size[i] for i in range(3))).normalized()
            biota_eyes.cap(A,'Inset respiratory nostril',at,normal,.016,.010,.001,'dark',q,recession=.004)
    return q

def ears(q,size=(.11,.10,.30),form='pointed'):
    for side in [-1,1]:
        if form=='round':A.oval('Rounded sensory ear',(side*.21,.04,.19),size,'secondary',q)
        else:A.leaf('Curved living pinna',[(side*.12,.09,.14),(side*.24,.02,.35),(side*.29,.10,.14+size[2])],size[0],'secondary',q)

def horn(q,side,kind='antler'):
    if kind=='coil':
        pts=[(side*(.18+.26*math.sin(i/20*math.pi)),.06+.16*i/20,.20+.30*math.sin(i/20*math.pi*.9)) for i in range(21)]
        A.sweep('Curved hollow sensory horn',pts,.07,'bone',q,[1-i*.036 for i in range(21)],24)
    else:
        pts=[(side*.12,0,.17),(side*.24,.03,.47),(side*.42,.08,.79),(side*.52,.13,.92)]
        A.sweep('Branching antler axis',pts,.055,'bone',q,[1,.82,.60,.15],24)
        for j in range(2):
            start=pts[j+1];end=(start[0]+side*.20,start[1]-.21,start[2]+.22)
            A.sweep('Antler sensory branch',[start,end],.045,'secondary',q,[1,.22],24)
            A.leaf('Terminal filter lamina',[end,(end[0]+side*.04,end[1]-.07,end[2]+.13),(end[0]+side*.12,end[1]-.02,end[2]+.22)],.085,'accent',q)

def integument(row,torso):
    """Attach adaptation details to the flank, leaving the body contour readable."""
    w,length,depth,z=torso;env=row['adaptation_id']
    if env in ('volcanic','cratered','crystalline'):
        for side in [-1,1]:
            for k in range(3):
                y=(k-1)*length*.43
                A.leaf('Overlapping protective flank plate',[(side*w*.66,y,z+depth*.65),(side*w*.99,y,z+.05),(side*w*.84,y,z-depth*.40)],length*.18,'bone')
    elif env in ('tundra','fractured','frozen'):
        for side in [-1,1]:
            for k in range(4):
                y=-length*.6+k*length*.34
                A.leaf('Thick insulating contour tuft',[(side*w*.60,y,z+depth*.5),(side*w*1.03,y+.06,z),(side*w*.83,y+.15,z-depth*.72)],.10,'secondary')
    elif env in ('salt','oxidized','alkaline'):
        for side in [-1,1]:
            A.oval('Integrated moisture reservoir',(side*w*.68,.16,z),(.18,length*.35,depth*.60),'secondary')
            A.X.cup('Protected excretion pore',(side*w*.67,.16,z+depth*.49),.035,.065,20,'accent')
    elif env=='ochre':
        for side in [-1,1]:A.leaf('Broad thermal exchange flank',[(side*w*.8,-length*.3,z),(side*w*1.18,0,z+depth*.34),(side*w*.75,length*.35,z)],.17,'secondary')

def lineage_organs(row,torso):
    w,length,depth,z=torso
    count=2 if row['organ_system'] in ('mandibles','sails') else 3
    anchors=[((0,(k-(count-1)*.5)*length*.42,z+depth*.84),0 if k%2 else math.pi) for k in range(count)]
    before=set(bpy.context.scene.objects);A.organ_system(row['organ_system'],anchors,count,row['anatomy'])
    for ob in set(bpy.context.scene.objects)-before:
        if ob.type=='EMPTY' and ob.parent==B.BODY:ob.scale*=.44

def quadruped(row):
    kind=row['construction'];torso,at,size,muzzle=PROFILES[kind];w,length,depth,z=torso
    A.oval('Continuous muscular rib cage',(0,0,z),(w,length,depth),'main')
    A.oval('Joined pelvic musculature',(0,length*.62,z-.05),(w*.88,length*.49,depth*.88),'main')
    neck_start=(0,-length*.62,z+depth*.09)
    A.curve('Continuous neck musculature',[neck_start,(0,(neck_start[1]+at[1])*.5,(neck_start[2]+at[2])*.5),at],min(w*.50,.24),'main')
    row['anatomical_scaffold']=[(0,length*.6,z),(0,0,z),neck_start,at]
    q=head(row,at,size,muzzle,kind)
    broad=kind in ('proboscid','rhinocerid','bovid');short=kind in ('gekkonid','skink','chelonian','crocodilian','monotreme')
    for index,y in enumerate([-length*.62,length*.58]):
        for side in [-1,1]:
            hip=(side*w*.76,y,z-.06);foot=(side*(w*.9+(.19 if short else .035)),y+(.09 if index else -.055),.105)
            knee=(side*(w+.25 if short else w*.86),y+(.22 if index else -.16),z*.49)
            style='hoof' if kind in ('cervid','giraffoid','camelid','bovid') else ('pad' if kind=='gekkonid' else ('web' if kind=='monotreme' else 'paw'))
            width=.18 if broad else (.055 if kind in ('giraffoid','cervid','skink') else .095)
            if kind=='anuran' and index:
                hip=(side*.30,.23,.36);knee=(side*.69,.46,.28);foot=(side*.52,.05,.085);width=.18;style='long'
            if kind=='lagomorph' and index:width=.17;knee=(side*.42,.34,.25);style='long';foot=(side*.34,.02,.09)
            if kind=='macropod':
                if index:
                    hip=(side*.23,.18,.89);knee=(side*.37,-.12,.51);foot=(side*.32,.02,.10);width=.18;style='long'
                else:
                    arm=B.pivot('Anim_Flex_Forearm_'+str(side),(side*.22,-.14,1.21),B.BODY)
                    A.curve('Small hanging forearm',[(0,0,0),(side*.055,-.17,-.16),(side*.08,-.29,-.24)],.060,'secondary',arm)
                    A.oval('Small grasping palm',(side*.08,-.29,-.24),(.08,.11,.055),'main',arm)
                    row.setdefault('anatomical_motion',{})[arm.name]={'axis':'x','amplitude':.06,'phase':side,'speed':1.2};continue
            phase=0 if (index==0)==(side<0) else math.pi
            if kind in ('anuran','lagomorph','macropod'):phase=index*math.pi
            limb(row,('F' if index==0 else 'H')+('L' if side<0 else 'R'),hip,knee,foot,width,style,phase,.08 if short else .14,.05 if short else .08)
    if kind=='cervid':
        ears(q)
        for side in [-1,1]:horn(q,side)
    elif kind=='giraffoid':
        ears(q,(.14,.10,.21))
        for side in [-1,1]:
            A.curve('Short sensory ossicone',[(side*.13,.07,.16),(side*.17,.08,.37)],.050,'secondary',q)
            for j in [-1,0,1]:A.leaf('Ossicone collecting vane',[(side*.16,.08,.30),(side*(.23+abs(j)*.035),.08+j*.08,.42),(side*.29,.08+j*.13,.43)],.055,'accent',q)
    elif kind=='bovid':
        for side in [-1,1]:horn(q,side,'coil')
        A.leaf('Insulating throat dewlap',[(0,-length*.45,z+.12),(0,-length*.66,z-.38),(0,-length*.88,z-.15)],.17,'secondary')
    elif kind=='proboscid':
        for side in [-1,1]:
            A.leaf('Broad articulated ear membrane',[(side*.30,.12,.17),(side*.71,.10,.17),(side*.67,.04,-.38)],.26,'secondary',q)
            A.sweep('Curved lateral tusk',[(side*.28,-.27,-.18),(side*.45,-.47,-.36),(side*.55,-.64,-.20)],.07,'bone',q,[1,.65,.08],24)
        nodes=chain(row,'Trunk',[(0,-.35,-.03),(0,-.56,-.34),(0,-.62,-.66),(0,-.80,-.78)],[.15,.115,.08],'main',q)
        for side in [-1,1]:A.curve('Opposed grasping trunk lip',[(0,-.18,-.12),(side*.09,-.25,-.15),(side*.14,-.23,-.06)],.035,'accent',nodes[-1])
        for side in [-1,1]:biota_eyes.cap(A,'Distal trunk nostril',(side*.025,-.184,-.121),(0,-.83,-.55),.017,.011,.002,'dark',nodes[-1])
    elif kind in ('canid','felid','mustelid','lagomorph','camelid'):
        ear_height=.60 if kind=='lagomorph' else (.12 if kind=='felid' else (.09 if kind=='mustelid' else .28))
        ears(q,(.105,.11,ear_height),'round' if kind in ('felid','mustelid') else 'pointed')
        if kind=='lagomorph':
            for side in [-1,1]:A.leaf('Forked pinna radiator',[(side*.23,.06,.42),(side*.41,.11,.65),(side*.38,.12,.83)],.09,'accent',q)
        if kind=='camelid':
            for y in [-.30,.34]:A.oval('Distinct dorsal water chamber',(0,y,z+.40),(.31,.34,.39),'secondary')
        if kind=='felid':
            for side in [-1,1]:
                for k in range(3):A.curve('Fine tapered tactile whisker',[(side*.115,-.355,-.09),(side*.32,-.41-k*.025,-.08-k*.012),(side*.45,-.44-k*.035,-.075-k*.022)],.006,'bone',q)
    elif kind=='rhinocerid':
        A.leaf('Blade shaped ceramic horn',[(0,-.35,.13),(0,-.43,.65),(0,-.62,.74)],.16,'bone',q)
        A.leaf('Smaller nasal horn',[(0,-.61,.05),(0,-.75,.38),(0,-.81,.39)],.095,'secondary',q)
        ears(q,(.10,.09,.23))
    if kind in ('chelonian','armadillo','pangolin'):
        if kind=='chelonian':
            A.oval('Thick vaulted dorsal shell',(0,0,z+.12),(w*1.03,length*1.01,depth*1.15),'secondary')
            for y in [-.40,0,.40]:
                for side in [-1,1]:
                    x=side*w*.29;top=z+.12+depth*1.15*math.sqrt(max(.1,1-(x/(w*1.03))**2-(y/(length*1.01))**2))
                    A.oval('Broad overlapping shell scute',(x,y,top-.025),(.25,.25,.06),'bone')
        elif kind=='armadillo':
            for j in range(6):
                y=(j-2.5)*.20
                pts=[(w*math.cos(i/24*math.pi),y,z+.31*math.sin(i/24*math.pi)) for i in range(25)]
                A.sweep('Flexible transverse armor band',pts,.084,'secondary',radii=[1]*25,sides=24)
        else:
            for j in range(6):
                y=(j-2.5)*.23
                for side in [-1,0,1]:A.leaf('Imbricated living scale',[(side*w*.6,y-.11,z+depth*(.92-.3*abs(side))),(side*w*.7,y+.10,z+depth*(1-.3*abs(side))),(side*w*.68,y+.27,z+depth*(.70-.3*abs(side)))],.16,'secondary')
    elif kind=='anuran':
        for side in [-1,1]:A.oval('Lateral resonating throat sac',(side*.42,-.38,.36),(.22,.25,.20),'accent')
    elif kind=='crocodilian':
        for j in range(8):A.leaf('Dorsal ceramic scute',[(0,-.78+j*.22,z+.17),(0,-.70+j*.22,z+.42),(0,-.60+j*.22,z+.19)],.12,'bone')
    if kind=='macropod':ears(q,(.09,.08,.35))
    if kind=='monotreme':
        tail=B.pivot('Anim_Tail',(0,length*.65,z),B.BODY)
        A.oval('Broad flattened steering tail',(0,.47,-.08),(.40,.64,.075),'secondary',tail)
        for k in [-1,0,1]:A.curve('Tail sensory ridge',[(k*.1,.04,0),(k*.23,.55,.0),(k*.15,.94,-.05)],.025,'accent',tail)
    elif kind not in ('anuran','chelonian'):
        tail_length={'canid':.72,'felid':1.02,'pangolin':1.25,'skink':1.40,'macropod':1.22,'lagomorph':.20,'crocodilian':1.30}.get(kind,.63)
        at_tail=(0,length*.72,z-depth*.2)
        tail_points=[at_tail,(.08,at_tail[1]+tail_length*.40,max(.15,z*.46)),(.16,at_tail[1]+tail_length*.78,.16),(.28,at_tail[1]+tail_length,.14)]
        radius=.17 if kind in ('pangolin','macropod','crocodilian') else (.13 if kind=='canid' else .07)
        chain(row,'Tail',tail_points,[radius,radius*.7,radius*.36])
    integument(row,torso);lineage_organs(row,torso)

def pincers(row,label,at,side,size=1.):
    shoulder=B.pivot('Anim_Flex_Pincer_'+label,at,B.BODY)
    A.curve('Jointed pedipalp',[(0,0,0),(side*.22*size,-.28*size,.08),(side*.29*size,-.53*size,.02)],.080*size,'main',shoulder)
    palm=B.pivot('Anim_Flex_Palm_'+label,(side*.29*size,-.53*size,.02),shoulder)
    A.oval('Muscular chela palm',(0,-.08,0),(.16*size,.24*size,.12*size),'secondary',palm)
    for direction in [-1,1]:
        finger=B.pivot('Anim_Flex_Finger_'+label+str(direction),(direction*.105*size,-.20*size,0),palm)
        A.sweep('Opposing curved pincer',[(0,0,0),(direction*.06*size,-.16*size,.01),(-direction*.06*size,-.33*size,0)],.070*size,'bone',finger,[1,.75,.12],24)
        row.setdefault('anatomical_motion',{})[finger.name]={'axis':'y','amplitude':.14,'phase':direction*1.4,'speed':1.5,'feeding':True}

def arthropod(row):
    kind=row['construction']
    configs={
     'arachnid':((.37,.43,.30,.53),(.44,.51,.39),(0,.66,.65),4),
     'scorpion':((.38,.67,.22,.46),(.27,.26,.18),(0,.48,.43),4),
     'crab':((.79,.52,.29,.50),(.34,.20,.16),(0,.30,.41),4),
     'hermit':((.42,.46,.26,.44),(.29,.48,.29),(.18,.47,.50),3),
     'mantid':((.19,.37,.28,.90),(.30,.77,.24),(0,.66,.56),2),
     'beetle':((.37,.39,.30,.50),(.57,.65,.39),(0,.65,.58),3),
    }
    torso,abdomen,abd_at,pairs=configs[kind];w,length,depth,z=torso
    A.oval('Distinct cephalothoracic compartment',(0,0,z),(w,length,depth),'main')
    A.oval('Joined visceral abdomen',abd_at,abdomen,'secondary')
    A.curve('Intercompartment living waist',[(0,0,z),abd_at],.18,'main')
    row['anatomical_scaffold']=[abd_at,(0,0,z),(0,-length*.7,z)]
    for i in range(pairs):
        for side in [-1,1]:
            y=-length*.57+i/max(1,pairs-1)*length*1.1
            hip=(side*w*.78,y,z-.03)
            spread=.65 if kind in ('arachnid','crab') else .43
            knee=(side*(w+spread*.67),y+(i-(pairs-1)*.5)*.17,z+.16)
            foot=(side*(w+spread),y+(i-(pairs-1)*.5)*.29,.085)
            if kind=='mantid':hip=(side*.14,.04+i*.45,.66);knee=(side*.52,.16+i*.52,.44);foot=(side*.70,.02+i*.75,.075)
            limb(row,str(i)+('L' if side<0 else 'R'),hip,knee,foot,.055 if kind!='crab' else .074,'point',math.pi*((i+(side>0))%2),.08,.07)
    if kind in ('scorpion','crab','hermit'):
        for side in [-1,1]:pincers(row,'L' if side<0 else 'R',(side*w*.58,-length*.57,z-.02),side,1.17 if kind=='hermit' and side>0 else .87)
    head_at=(0,-length*.82,z+.05)
    if kind=='mantid':head_at=(0,-.36,1.30);A.curve('Long narrow cervical prothorax',[(0,0,z),head_at],.13,'secondary')
    q=B.pivot('Anim_Head',head_at,B.BODY)
    A.oval('Integrated feeding head',(0,-.08,0),(.20 if kind!='mantid' else .32,.20,.13),'secondary',q)
    for side in [-1,1]:
        eye_at=(side*.20,-.13,.07)
        if kind in ('crab','hermit'):
            A.curve('Protected eye stalk',[(side*.14,0,.02),(side*.23,-.09,.25)],.039,'secondary',q);eye_at=(side*.23,-.09,.25)
        if kind=='arachnid':
            A.sweep('Curved tapered cheliceral fang',[(side*.11,-.23,-.045),(side*.13,-.32,-.10),(side*.05,-.38,-.14)],.049,'secondary',q,[1,.68,.06],24)
        else:A.sweep('Tapered opposing mouthpart',[(side*.12,-.18,-.05),(side*.18,-.32,-.03),(side*.07,-.41,-.01)],.038,'bone',q,[1,.8,.08],24)
        if kind in ('beetle','mantid'):A.curve('Paired tactile antenna',[(side*.12,.02,.10),(side*.24,-.11,.45),(side*.35,-.27,.64)],.020,'accent',q)
    biota_eyes.arthropod(A,row,q,kind)
    if kind=='scorpion':
        chain(row,'Sting',[(0,.55,.48),(0,.89,.66),(0,1.00,1.02),(0,.76,1.31),(0,.37,1.31),(0,.12,1.14)],[.14,.13,.11,.09,.067],'secondary')
    elif kind=='hermit':
        pts=[]
        for i in range(75):
            a=i/74*math.tau*1.55;r=.12+.43*i/74
            pts.append((.22+math.cos(a)*r,.63+math.sin(a)*r,.65+i/74*.74))
        A.curve('Continuous eccentric living shell',pts,.20,'bone')
    elif kind=='mantid':
        for side in [-1,1]:
            arm=B.pivot('Anim_Flex_Raptorial_'+str(side),(side*.13,-.22,1.08),B.BODY)
            A.curve('Raptorial proximal arm',[(0,0,0),(side*.22,-.36,-.14)],.065,'secondary',arm)
            elbow=B.pivot('Anim_Flex_RaptorialElbow_'+str(side),(side*.22,-.36,-.14),arm)
            A.curve('Folded grasping tibia',[(0,0,0),(-side*.12,.19,-.19),(-side*.10,.30,-.12)],.055,'main',elbow)
            for i in range(4):A.curve('Grasping arm tooth',[(0,-i*.055,-.025),(-side*.10,-i*.055,-.10)],.022,'bone',elbow)
            row.setdefault('anatomical_motion',{})[elbow.name]={'axis':'x','amplitude':.22,'phase':side,'speed':1.4,'feeding':True}
    elif kind=='beetle':
        for side in [-1,1]:
            cover=B.pivot('Anim_Flex_Elytron_'+str(side),(side*.035,.21,.82),B.BODY)
            A.oval('Separate protective elytron',(side*.28,.40,-.005),(.29,.60,.22),'bone',cover)
            row.setdefault('anatomical_motion',{})[cover.name]={'axis':'z','amplitude':.075,'phase':side,'speed':.7}
        A.leaf('Forked head shield',[(0,-.32,.58),(0,-.57,.95),(0,-.79,.99)],.13,'secondary')
    integument(row,torso);lineage_organs(row,torso)

def serpent(row):
    points=[(.40*math.sin(i*.76),(i/10-.5)*3.8,.20+.04*math.cos(i*.76)) for i in range(11)]
    # Continuous mesh with weights along the curved, species-specific spine.
    A.sweep('Continuous limbless muscular trunk',points,.19,'main',radii=[.82,1,1.1,1.1,1.0,.9,.8,.66,.5,.33,.07],sides=32)
    row['anatomical_scaffold']=points[:9];row['anatomical_scaffold_parents']=[-1]+list(range(8))
    q=head(row,points[0],(.24,.32,.16),.17,'serpent')
    for side in [-1,1]:
        A.leaf('Thick lateral sensing hood',[(side*.12,.10,.01),(side*.47,.46,.25),(side*.19,.87,.02)],.23,'secondary',q)
        for k in range(3):A.curve('Hood chemosensory rib',[(side*.13,.20+k*.13,.03),(side*.39,.28+k*.13,.21)],.035,'accent',q)
    integument(row,(.31,1.1,.17,.22))
    lineage_organs(row,(.26,.7,.18,.22))

def build(row,api):
    global A,B
    A=api;B=A.B
    if row['construction'] in PROFILES:quadruped(row)
    elif row['construction']=='serpent':serpent(row)
    else:arthropod(row)
