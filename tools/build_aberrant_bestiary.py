"""100 additional authored anatomical forms. Never modifies the original 500 exports.
Blender: --background --python tools/build_aberrant_bestiary.py [-- family_or_id]
"""
from pathlib import Path
import sys,json,math,colorsys,bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_bestiary as B
from mathutils import Vector
from build_bestiary import oval,link,horn,tube,blade,pivot
TAU=math.tau
FAMILIES=[
 ('blind_harp','공명늑골체','none',['cave','thermal','marine','cold','basalt'],'진동을 읽는 빈 늑골과 장력 섬유'),
 ('spiral_maw','나선구강체','bite',['cave','acid','marine','thermal','wetland'],'빛 대신 구강 촉수의 화학 감각'),
 ('tripod_bell','삼각종보행체','slam',['basalt','arid','thermal','crystal','cave'],'다리 말단과 종 내부의 압력 감각'),
 ('lantern_sail','유막부유체','none',['marine','cave','wetland','cold','thermal'],'막 전체의 전기·유속 감각'),
 ('eye_orchard','수지다안체','spit',['canopy','wetland','cave','temperate','acid'],'비대칭 줄기 끝의 세로 동공'),
 ('asym_pincer','편측집게체','claw',['marine','basalt','acid','cold','arid'],'한쪽 측면의 단일 동심 렌즈'),
 ('ribbon_colony','주름띠군체','none',['marine','wetland','cave','cold','acid'],'몸통의 분산된 납작한 안점'),
 ('window_sac','창낭보행체','spit',['cave','crystal','thermal','marine','acid'],'갈라진 외피 안쪽의 단일 긴 감광 틈'),
 ('crown_stalker','복안관추적체','scythe',['crystal','arid','canopy','basalt','temperate'],'개별 눈알 없이 이어진 다면 복안면'),
 ('manymouth','분지다구체','bite',['cave','wetland','acid','thermal','canopy'],'분지된 여러 입과 불규칙 감각 결절'),
]
SCHEMA=1

def ring(name,center,rx,rz,thickness,slot='secondary',parent=None,phase=0):
 # Vertical annulus; the interior is actual empty geometry, never a painted eye.
 cx,cy,cz=center
 pts=[(cx+rx*math.cos(TAU*k/24+phase),cy,cz+rz*math.sin(TAU*k/24+phase)) for k in range(25)]
 return tube(name,pts,thickness,slot,parent)

def feet(n,z,r,spread,v):
 for k in range(n):
  a=TAU*k/n+.21*v;p=pivot('Anim_Leg_%d_%s'%(k,'L' if k%2 else 'R'),(r*math.cos(a),r*math.sin(a),z),B.BODY)
  dx,dy=math.cos(a)*spread,math.sin(a)*spread
  tube('Crooked support',[(0,0,0),(dx*.8,dy*.8,.18),(dx,dy,-z+.14)],.095,'secondary',p)
  horn('Contact spur',(dx,dy,-z+.14),(dx*1.18,dy*1.18,-z+.02),.11,'bone',p)

def mouth(center,r,n,parent,depth=.20):
 x,y,z=center
 oval('Recessed mouth cavity',(x,y+.06,z),(r,.09,r),'dark',parent)
 ring('Raised oral lip',center,r,r*.94,.09,'main',parent)
 for k in range(n):
  a=TAU*k/n
  horn('Inward tooth',(x+r*.9*math.cos(a),y-.02,z+r*.84*math.sin(a)),(x+r*.50*math.cos(a+.1),y-depth,z+r*.47*math.sin(a+.1)),r*.12,'bone',parent)

def aperture(center,size,kind,parent):
 x,y,z=center
 if kind=='slit':
  oval('Elongated ocular capsule',(x,y,z),(size*.62,size*.42,size*1.18),'secondary',parent)
  oval('Vertical iris',(x,y-size*.35,z),(size*.31,.045,size*.90),'accent',parent)
  oval('Needle pupil',(x,y-size*.35-.055,z),(size*.075,.03,size*.75),'dark',parent)
 elif kind=='pit':
  oval('Flat dermal eye socket',center,(size,.035,size*.62),'secondary',parent)
  oval('Dermal photoreceptor',(x,y-.035,z),(size*.63,.023,size*.37),'eye',parent)
  oval('Oblique pit pupil',(x,y-.056,z),(size*.35,.016,size*.09),'dark',parent).rotation_euler.y=.6
 elif kind=='concentric':
  oval('Single dark sclera',center,(size,.10,size),'dark',parent)
  ring('Outer sensory whorl',(x,y-.08,z),size*.78,size*.78,.065,'accent',parent)
  ring('Inner sensory whorl',(x,y-.12,z),size*.45,size*.45,.04,'bone',parent)
  oval('Off-center aperture',(x+size*.10,y-.15,z-size*.08),(size*.16,.03,size*.29),'dark',parent)

def construct(f,v):
 t=v/9;eyes=0;body=B.BODY
 if f=='blind_harp':
  n=4+v%5;length=1.4+t*.8
  tube('Low axial spine',[(0,-length/2,.25),(0,0,.38),(0,length/2,.3)],.15,'main')
  for k in range(n):
   y=-length/2+length*k/(n-1);h=1.25+.5*math.sin(k/(n-1)*math.pi)+t*.2
   p=pivot('Anim_Appendage_%d'%k,(0,y,.3),body)
   tube('Open rib arch',[(-.7,0,0),(-.75,0,h*.6),(0,.04,h),(.65,0,h*.55),(.55,0,0)],.10,'bone',p)
   for j in range(2+v%3):
    x=-.35+j*.23;tube('Resonance filament',[(x,0,.04),(x+.1,.1,h*.4),(x*.5,0,h*.87)],.022,'accent',p)
  feet(4+v%2,.35,.34,.56,v)
 elif f=='spiral_maw':
  p=pivot('Anim_Jaw',(0,-.28,1.03),body);r=.62+t*.17
  mouth((0,0,0),r,9+v,p)
  for k in range(5+v%4):
   a=k*TAU/(5+v%4);q=pivot('Anim_Appendage_%d'%k,(r*math.cos(a),0,1.03+r*math.sin(a)),body)
   tube('Coiling oral limb',[(0,0,0),(.35*math.cos(a+.3),.1,.35*math.sin(a+.3)),(.65*math.cos(a+1),.3,.65*math.sin(a+1)),(.62*math.cos(a+1.9),.22,.62*math.sin(a+1.9))],.10,'secondary',q)
  ring('Rear muscular torus',(0,.18,1.03),r*.92,r*.92,.22,'main');feet(3+v%3,.48,.35,.45,v)
  pivot('FX_Mouth',(0,-.60,1.03),body)
 elif f=='tripod_bell':
  z=1.3+t*.35
  for k in range(3):
   a=TAU*k/3+.2;q=pivot('Anim_Leg_%d_R'%k,(.32*math.cos(a),.32*math.sin(a),z),body)
   tube('Arched tripod',[(0,0,0),(.68*math.cos(a),.68*math.sin(a),.20),(1.02*math.cos(a),1.02*math.sin(a),-z+.07)],.15,'bone',q)
  oval('Hanging bell core',(0,0,z),(.48,.48,.48),'main')
  for k in range(6+v):
   a=TAU*k/(6+v);p=pivot('Anim_Petal_%d'%k,(0,0,z),body)
   tube('Flared rib',[(.15*math.cos(a),.15*math.sin(a),.33),(.5*math.cos(a),.5*math.sin(a),-.1),(.68*math.cos(a),.68*math.sin(a),-.36)],.09,'secondary',p)
  for k in range(3+v%3):ring('Underside pressure folds',(0,-.41,z-.1-k*.12),.25-k*.035,.045,.022,'dark')
 elif f=='lantern_sail':
  h=1.8+t*.6;n=3+v%5
  for k in range(n):
   a=TAU*k/n;p=pivot('Anim_Frond_%d'%k,(0,0,.75),body);p.rotation_euler.z=a
   blade('Ribbed sensory membrane',[(0,0,0),(.3,-.10,h*.2),(.65,0,h*.52),(.25,.04,h*.77),(0,0,h)],.40+t*.16,'main' if k%2 else 'secondary',p)
   tube('Membrane leading seam',[(0,0,0),(.55,0,h*.5),(0,0,h)],.05,'bone',p)
   tube('Trailing electroreceptor',[(0,0,.1),(.22,.25,-.25),(.45,.15,-.7)],.035,'accent',p)
  oval('Buoyancy spindle',(0,0,1.4),(.14,.17,.66),'accent')
 elif f=='eye_orchard':
  n=5+v;eyes=n
  oval('Rooted muscular caudex',(0,0,.48),(.62,.45,.44),'main');feet(3+v%3,.4,.34,.34,v)
  for k in range(n):
   a=k*2.399;r=.50+(k%3)*.18;h=1.05+(k%4)*.24+t*.2
   q=pivot('Anim_Appendage_%d'%k,(0,0,.60),body);x=r*math.cos(a);y=r*math.sin(a)*.45
   tube('Asymmetric ocular branch',[(0,0,0),(x*.8,y,.4),(x,y,h-.6)],.06,'secondary',q)
   aperture((x,y-.04,h-.6),.15+(k%3)*.025,'slit',q)
  q=pivot('Anim_Jaw',(0,-.4,.6),body);mouth((0,0,0),.23,6,q);pivot('FX_Mouth',(0,-.78,.6),body)
 elif f=='asym_pincer':
  eyes=1;oval('Unequal torso',(.2,.10,.78),(.61,.69,.59),'main');feet(3+v%4,.6,.35,.40,v)
  aperture((.42,-.53,1.0),.30+t*.10,'concentric',body)
  p=pivot('Anim_Arm_L',(-.35,-.2,.8),body)
  tube('Oversized single claw arm',[(0,0,0),(-.65,-.15,.2),(-.72,-.4,.7)],.23,'secondary',p)
  tube('Long outer chela',[(-.72,-.4,.7),(-1.02,-.5,1.12),(-.75,-.55,1.55+t*.3),(-.48,-.6,1.32)],.15,'bone',p)
  tube('Opposing short chela',[(-.65,-.4,.72),(-.30,-.48,.98),(-.42,-.57,1.2)],.12,'accent',p)
  for k in range(3+v):horn('Uneven dorsal spur',(.12,.1+k*.045,1.22),(.25+k*.035,.2+k*.08,1.5+(k%3)*.13),.08,'secondary')
 elif f=='ribbon_colony':
  n=9+v;eyes=n
  for k in range(n):
   a=k*.48;pos=(math.sin(a)*.8,(k/(n-1)-.5)*2.5,.48+.35*math.sin(a*.8)**2)
   p=pivot('Anim_Segment_%d'%k,pos,body)
   oval('Overlapping folded ribbon',(0,0,0),(.48,.25,.22),'main',p)
   blade('Raised pleated edge',[(-.30,0,0),(-.12,.04,.48+t*.2),(.24,0,.10)],.12,'secondary',p)
   aperture((.03,-.215,.08),.15,'pit',p)
   tube('Chemosensory fringe',[(.30,0,0),(.6,.05,-.12),(.72,.13,-.30)],.032,'accent',p)
 elif f=='window_sac':
  eyes=1;z=1.17;feet(4+v%3,.7,.28,.65,v)
  # Wide actual gap between two thick organic shell halves, interior slit visible.
  for side in [-1,1]:
   oval('Separated curved shell',(side*.45,0,z),(.29,.45,.80+t*.2),'main')
   for k in range(3+v%4):
    tube('Shell window buttress',[(side*.1,.22,.62+k*.22),(side*.57,.35,.73+k*.22),(side*.60,0,.9+k*.22)],.055,'bone')
  oval('Internal receptor sac',(0,.04,z),(.25,.25,.68),'secondary')
  oval('Single vertical photoreceptor',(0,-.23,z),(.11,.055,.61),'accent')
  oval('Long internal pupil',(0,-.285,z),(.026,.02,.48),'dark')
  q=pivot('Anim_Jaw',(0,-.29,.61),body);mouth((0,0,0),.16,5+v%4,q);pivot('FX_Mouth',(0,-.63,.6),body)
 elif f=='crown_stalker':
  eyes=1;n=12+v*2
  oval('Faceted crown substrate',(0,0,1.22),(.63,.36,.65),'dark');feet(5+v%4,.82,.30,.75,v)
  for k in range(n):
   a=k*2.399;r=.52*math.sqrt((k+.5)/n);x=r*math.cos(a);z=1.22+r*math.sin(a)
   # Lens facets, one compound surface; no mammalian sclera/pupils.
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.14,location=(x,-.34,z));o=bpy.context.object;o.scale=(1,.48,1)
   B.finish(o,'Compound lens facet','accent' if k%3 else 'eye',body,0,False)
  for k in range(4+v%4):
   a=math.pi*k/(3+v%4);horn('Crown radiating blade',(.58*math.cos(a),0,1.22+.58*math.sin(a)),(.95*math.cos(a),.1,1.22+.95*math.sin(a)),.085,'bone')
  for side in [-1,1]:
   p=pivot('Anim_Arm_'+('L' if side<0 else 'R'),(side*.43,-.05,.94),body)
   tube('Scythe sensory limb',[(0,0,0),(side*.6,-.3,.17),(side*.78,-.75,-.1),(side*.53,-1,-.3)],.075,'bone',p)
 elif f=='manymouth':
  n=3+v%5;eyes=v%5
  oval('Central branching knot',(0,.1,.64),(.46,.38,.53),'main');feet(3+v%3,.4,.28,.4,v)
  for k in range(n):
   a=k*2.399;x=math.cos(a)*(.6+k*.035);z=.9+math.sin(a)*.4+k*.12
   p=pivot('Anim_Jaw' if k==0 else 'Anim_Petal_%d'%k,(x,-.15,z),body)
   tube('Bent oral neck',[(-x,.3,.64-z),(-x*.4,.15,-.2),(0,0,0)],.17,'secondary',p)
   mouth((0,-.14,0),.24+(k%2)*.1,6+k,p)
  for k in range(eyes):aperture((-.24+k*.13,-.24,.46+k*.15),.075,'pit',body)
  pivot('FX_Mouth',(.6,-.7,.9),body)
 return eyes

def generate():
 catalog_path=B.DATA/'forms.json';look_path=B.DATA/'appearances.json'
 previous=json.loads(catalog_path.read_text());old_looks=json.loads(look_path.read_text())
 forms=[r for r in previous['forms'] if r.get('collection')!='aberrant'];looks=[r for r in old_looks['appearances'] if r['form_id'] in {f['id'] for f in forms}]
 for family,label,attack,envs,sensory in FAMILIES:
  for v in range(10):
   id='bio_'+family+'_%02d'%(v+1);env=envs[v//2];cfg=B.ENVIRONMENTS[env];record=B.SRC/(id+'.json')
   existing=json.loads(record.read_text()) if record.exists() else {}
   schema=2 if family=='eye_orchard' else SCHEMA
   if existing.get('form_schema')==schema and all((B.ROOT/x['path']).exists() for x in existing.get('lods',{}).values()) and len(existing.get('lods',{}))==2:row=existing
   elif not B.LIMIT or family in B.LIMIT or id in B.LIMIT:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    B.M={key:B.material(key,B.rgb(c),emit=.10 if key=='eye' else 0) for key,c in {'main':cfg['palette'][0],'secondary':cfg['palette'][1],'accent':cfg['palette'][2],'dark':'101622','bone':'bbb8ad','eye':'6d938e'}.items()}
    B.BODY=pivot('Anim_Body');eyes=construct(family,v)
    row={'form_schema':schema,'id':id,'name':label+' · '+['공동형','장축형','분절형','확공형','밀생형','편향형','고관형','다지형','방사형','극변형'][v],'family':family,'family_name':label,'category':'animal','collection':'aberrant','environment':env,'environment_label':cfg['label'],'habitat_note':cfg['condition'],'morphology':v,'anatomy':v,'eye_count':eyes,'sensory_type':sensory,'attack':attack,'render_status':'generated-unverified','spawn_enabled':False,'palette':cfg['palette'],'variant_count':20}
    B.export_form(row);record.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');print('ABERRANT_FORM_COMPLETE',id,flush=True)
   else:continue
   forms.append(row)
   for p in range(5):
    adjusted=[]
    for c in cfg['palette']:
     h,s,val=colorsys.rgb_to_hsv(*B.rgb(c));cs=colorsys.hsv_to_rgb((h+(p-2)*.013)%1,max(.1,min(.9,s*(.85+p*.075))),max(.15,min(.88,val*(.90+p*.045))))
     adjusted.append(''.join('%02x'%round(x*255) for x in cs))
    for sz in range(4):looks.append({'id':id+'_p%02d_s%02d'%(p,sz),'form_id':id,'environment':env,'palette_index':p,'size_index':sz,'palette':adjusted,'scale':round(.88+sz*.08,3),'type':'appearance-variant','spawn_enabled':False})
 previous.update(families=len({r['family'] for r in forms}),form_count=len(forms),forms=forms)
 catalog_path.write_text(json.dumps(previous,ensure_ascii=False,indent=2)+'\n');old_looks.update(count=len(looks),appearances=looks);look_path.write_text(json.dumps(old_looks,ensure_ascii=False,separators=(',',':'))+'\n')
 print('ABERRANT_BUILD_COMPLETE',len(forms),len(looks),flush=True)
if __name__=='__main__':generate()
