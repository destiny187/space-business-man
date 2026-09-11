"""Embedded ocular anatomy, with authored lids and optically distinct surfaces.

No bright identical spheres: lens apertures, socket depth, rim and compound
facets follow the animal's head. This is fictional anatomy informed by references.
"""
import math
from mathutils import Vector

HORIZONTAL={'cervid','giraffoid','camelid','bovid','macropod','anuran'}
VERTICAL={'felid','crocodilian','gekkonid','skink','serpent'}
SMALL={'proboscid','rhinocerid','monotreme','pangolin','armadillo','mustelid'}
IRIS={
 'cervid':'8a6030','proboscid':'4c3320','canid':'ac7530','felid':'aca43b',
 'chelonian':'886c35','crocodilian':'a78e36','giraffoid':'745033','camelid':'7c6548',
 'rhinocerid':'523c25','bovid':'a6814a','anuran':'c1a149','monotreme':'44392d',
 'pangolin':'534638','armadillo':'604b35','gekkonid':'b98b46','skink':'81694c',
 'macropod':'9c7647','lagomorph':'946846','mustelid':'645039','serpent':'b0a047',
 'wader':'a1924f','owl':'c59831','arachnid':'172c34','scorpion':'19262b',
 'crab':'394b43','hermit':'403d30','mantid':'65794b','beetle':'30443a',
}


def materials(api,kind):
    if 'ocular_iris' in api.B.M:return
    base=api.B.rgb(IRIS[kind])
    for name,color,rough in [
        ('ocular_iris',base,.30),
        ('ocular_fiber',tuple(min(.72,c*1.30+.025) for c in base),.40),
        ('ocular_shadow',tuple(c*.48 for c in base),.42),
        ('ocular_pupil',(.007,.011,.013),.20),
    ]:
        api.B.M[name]=api.B.material(name,color,rough=rough,emit=0)


def frame(normal):
    normal=Vector(normal).normalized()
    up=Vector((0,0,1))
    if abs(normal.dot(up))>.90:up=Vector((0,-1,0))
    right=up.cross(normal).normalized()
    up=normal.cross(right).normalized()
    return right,up,normal


def cap(api,name,center,normal,width,height,depth,slot,owner,almond=False,recession=0.,support=None):
    c=Vector(center);right,up,n=frame(normal);verts=[tuple(c+n*depth)];faces=[]
    sectors=40;rings=7
    for ring in range(1,rings+1):
        r=ring/rings
        for k in range(sectors):
            a=k*math.tau/sectors;sy=math.sin(a)
            z=math.copysign(abs(sy)**1.38,sy) if almond else sy
            x=width*r*math.cos(a);y=height*r*z
            d=depth*math.sqrt(max(0,1-r*r))-recession*r*r
            if support:
                sw,sh,sd,sr=support;radius=min(.999,(x/sw)**2+(y/sh)**2)
                d+=sd*math.sqrt(1-radius)-sr*radius
            verts.append(tuple(c+right*x+up*y+n*d))
    if support:verts[0]=tuple(c+n*(depth+support[2]))
    for k in range(sectors):faces.append((0,1+k,1+(k+1)%sectors))
    for ring in range(rings-1):
        for k in range(sectors):
            a=1+ring*sectors+k;b=1+ring*sectors+(k+1)%sectors
            faces.append((a,a+sectors,b+sectors,b))
    return api.mesh(name,verts,faces,slot,owner)


def lid(api,owner,center,normal,width,height,upper=True,heavy=False,slot='secondary'):
    c=Vector(center);right,up,n=frame(normal);points=[]
    for k in range(13):
        a=k/12*math.pi+(0 if upper else math.pi)
        recess=width*((.08 if upper else .04)+.18*math.cos(a)**2)
        points.append(tuple(c+right*(width*math.cos(a))+up*(height*math.sin(a))-n*recess))
    api.sweep('Sculpted upper orbital fold' if upper else 'Fine lower orbital rim',points,width*(.14 if heavy and upper else (.075 if upper else .030)),slot,owner,[.30]+[1]*11+[.30],12)


def lens(api,row,owner,center,normal,width,height,kind,design=None):
    materials(api,kind)
    design=design or ('horizontal' if kind in HORIZONTAL else ('vertical' if kind in VERTICAL else 'round'))
    c=Vector(center);right,up,n=frame(normal)
    almond=design in ('horizontal','vertical') or kind in SMALL
    # Shallow concentric surfaces bury the eye within a dark socket. The face
    # shows an aperture; a complete pale eyeball never sits outside the skull.
    cap(api,'Recessed orbital aperture',c-n*width*.10,n,width*1.08,height*1.10,width*.18,'ocular_pupil',owner,almond,width*.24)
    cap(api,'Convex pigmented iris',c,n,width,height,width*.28,'ocular_iris',owner,almond,width*.35)
    for k in range(10):
        a=k/10*math.tau
        if design=='horizontal' and abs(math.sin(a))<.24:continue
        r0=.58 if design=='round' else .40;r1=.91
        pts=[]
        for r in [r0,(r0+r1)*.5,r1]:
            theta=a+.09*math.sin(r*4)
            pts.append(tuple(c+right*(width*r*math.cos(theta))+up*(height*r*math.sin(theta))+n*(width*.28*math.sqrt(1-r*r)-width*.35*r*r+.0005)))
        api.sweep('Radial iris fiber',pts,width*.008,'ocular_fiber',owner,[.4,1,.2],6)
    if design=='horizontal':pw,ph=width*.76,height*.22
    elif design=='vertical':pw,ph=width*.19,height*.81
    elif kind in SMALL:pw,ph=width*.57,height*.66
    else:pw,ph=width*.49,height*.58
    cap(api,'Actual dark pupil aperture',c+n*.0008,n,pw,ph,width*.015,'ocular_pupil',owner,design!='round',support=(width,height,width*.28,width*.35))
    heavy=kind in {'camelid','rhinocerid','crocodilian','armadillo','owl','felid'}
    lid(api,owner,c,n,width*1.08,height*1.05,True,heavy,'main')
    lid(api,owner,c,n,width*1.08,height*1.05,False,False,'main')
    if kind in {'cervid','giraffoid','camelid'}:
        for k in [-1,0,1]:
            u=k*.46;start=c+up*height*math.sqrt(1-u*u)+right*width*u-n*width*(.08+.18*u*u)
            api.sweep('Protective upper lash ridge',[tuple(start),tuple(start+up*height*.18+n*width*.07)],width*.030,'dark',owner,[1,.12],8)
    if kind in {'crocodilian','skink','serpent','chelonian'}:
        for k in [-1,0,1]:
            at=c+up*height*1.32+right*width*k*.73-n*width*.10
            ob=api.oval('Imbricated supraocular scale',(0,0,0),(width*.43,width*.23,height*.21),'bone',owner)
            for vertex in ob.data.vertices:
                p=vertex.co.copy();vertex.co=at+right*p.x+n*p.y+up*p.z
    if kind in {'proboscid','rhinocerid','pangolin','armadillo'}:
        lid(api,owner,c-n*width*.09,n,width*1.40,height*1.43,True,True,'main')


def simple(api,owner,center,normal,width,height,kind):
    materials(api,kind);c=Vector(center);_,_,n=frame(normal)
    cap(api,'Sclerotized simple-eye socket',c-n*width*.08,n,width*1.12,height*1.12,width*.18,'secondary',owner)
    cap(api,'Dark single-lens ocellus',c,n,width,height,width*.45,'ocular_pupil',owner)


def compound(api,owner,center,normal,width,height,kind):
    materials(api,kind);c=Vector(center);right,up,n=frame(normal)
    cap(api,'Compound ocular carapace rim',c-n*width*.10,n,width*1.10,height*1.09,width*.32,'dark',owner)
    cap(api,'Continuous compound retina',c,n,width,height,width*.43,'ocular_shadow',owner)
    # Hexagonal lens caps follow the ovoid surface. Each belongs to the same
    # head; the eye has many lenses and no vertebrate iris or pupil.
    radius=.15
    for row_index in range(-5,6):
        for column in range(-5,6):
            ux=math.sqrt(3)*radius*(column+.5*(row_index%2));uz=1.5*radius*row_index
            if ux*ux+uz*uz>.72:continue
            verts=[]
            for k in range(6):
                a=math.tau*k/6+math.pi/6;x=ux+radius*.94*math.cos(a);z=uz+radius*.94*math.sin(a)
                d=width*.43*math.sqrt(max(.03,1-x*x-z*z))+.001
                verts.append(tuple(c+right*width*x+up*height*z+n*d))
            tile=api.mesh('Individual hexagonal corneal lens',verts,[(0,1,2,3,4,5)],'ocular_fiber' if (row_index+column)%4==0 else 'ocular_iris',owner)
            for face in tile.data.polygons:face.use_smooth=False


def sculpt_socket(cranium,center,normal,width,height):
    c=Vector(center);right,up,n=frame(normal)
    for vertex in cranium.data.vertices:
        delta=vertex.co-c
        if delta.dot(n)<-width*1.8:continue
        radius=(delta.dot(right)/(width*1.35))**2+(delta.dot(up)/(height*1.45))**2
        if radius<1:
            vertex.co-=n*(width*.46*(1-radius)**2)
    cranium.data.update()


def vertebrate(api,row,owner,size,kind,cranium):
    w,length,h=size
    for side in [-1,1]:
        if kind=='anuran':u=Vector((side*.69,-.43,.58));width,height=.097,.060
        elif kind=='gekkonid':u=Vector((side*.78,-.40,.48));width,height=.096,.089
        elif kind=='crocodilian':u=Vector((side*.64,-.30,.72));width,height=.065,.047
        elif kind in SMALL:u=Vector((side*.87,-.42,.21));width,height=(.046,.033) if w>.30 else (.034,.027)
        else:
            u=Vector((side*.84,-.48,.24));width=min(.078,w*.29)
            height=width*(.52 if kind in HORIZONTAL else (.85 if kind=='felid' else .70))
        u.normalize();at=Vector((u.x*w,u.y*length,u.z*h))
        normal=Vector((u.x/w,u.y/length,u.z/h)).normalized()
        sculpt_socket(cranium,at,normal,width,height)
        lens(api,row,owner,at,normal,width,height,kind)


def arthropod(api,row,owner,kind):
    for side in [-1,1]:
        if kind=='arachnid':
            simple(api,owner,(side*.066,-.263,.035),(side*.1,-1,.08),.056,.058,kind)
            simple(api,owner,(side*.153,-.205,.074),(side*.55,-.72,.25),.027,.031,kind)
            simple(api,owner,(side*.188,-.095,.070),(side*.85,-.3,.3),.022,.024,kind)
        elif kind=='scorpion':
            simple(api,owner,(side*.054,-.071,.133),(side*.1,-.2,1),.025,.031,kind)
        elif kind in ('crab','hermit'):
            compound(api,owner,(side*.23,-.09,.25),(side*.30,-.94,.14),.060,.095 if kind=='crab' else .071,kind)
        elif kind=='mantid':
            compound(api,owner,(side*.253,-.145,.035),(side*.70,-.72,.23),.112,.095,kind)
        else:
            compound(api,owner,(side*.166,-.143,.035),(side*.84,-.50,.19),.067,.080,kind)


def avian(api,row,owner,kind):
    for side in [-1,1]:
        if kind=='owl':
            lens(api,row,owner,(side*.16,.229,.07),(side*.10,.994,.035),.099,.111,kind)
        else:
            lens(api,row,owner,(side*.154,.136,.063),(side*.78,.61,.12),.042,.037,kind)
