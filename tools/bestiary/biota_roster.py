"""Reviewed construction recipes for 7,000 new fictional base organisms.

140 structural groups × 50 anatomies. Palette/whole-body scale do not define species.
Scientific sources are references for organs and growth, not copied characters/assets.
"""
from pathlib import Path
import json
from biota_midpoint import replacement

ROOT=Path(__file__).resolve().parents[2]
COLLECTION='biota-7000'
ENVIRONMENTS=['basalt','arid','cold','cave','temperate','crystal','thermal']
ADAPTATIONS=[
 ('oxidized','arid','저수','수분을 보존하는 외피와 연결된 저장낭'),
 ('continental','temperate','집광','넓은 광합성·감각 면과 여과 기관'),
 ('cratered','basalt','차폐','저압 먼지에 노출된 감각기관을 감싸는 차폐판'),
 ('fractured','cold','단열','짧은 말단과 두꺼운 단열 외피'),
 ('tundra','cold','융빙','기저 저장층과 짧은 단열 주름'),
 ('frozen','cold','동결','작은 개구부·겹친 단열막의 가상 극저온 생리'),
 ('volcanic','thermal','차열','겹친 광물성 차열판·좁은 보호 기공의 가상 고온 생리'),
 ('salt','arid','염류','외부 염류를 모으는 배출낭과 보호된 흡수면'),
 ('ochre','thermal','열수','열을 분산하는 넓은 기관과 기질 여과관'),
 ('sedimentary','basalt','퇴적','기질에 닿는 넓은 흡착면과 여과 부속기관'),
 ('crystalline','crystal','광각','광물 피막과 모서리를 피해 열린 감각면'),
 ('alkaline','crystal','완충','외부 물질과 내부 대사를 분리하는 두꺼운 낭벽'),
]
FLIGHT_ANATOMIES={0,1,2,3,9,10,11,12,18,19,20,21,24,25,27,29,30,34,39,49}
FLIGHT_HABITATS=['continental','tundra','salt','sedimentary','ochre']
GAS_ARCHETYPES=['banded','storm','pale','azure','turquoise','violet']

# Each named construction combines a body organization with a distinct functional
# organ system. The authoring code gives the seven organ systems different meshes.
ANIMAL_GROUPS=[
 ('spindle','유선근체','등갑영양 목깃도약수 큰턱능선수 부채촉각수 장관주둥이수 측막질주수 분지꼬리수'),
 ('lobopod','엽족체','관족완보수 털아가미완보수 돌기턱벌레 촉수나방수 접이입엽족수 막등엽족수 뿌리꼬리엽족수'),
 ('radial','방사체','돌갑불가사리 깃털방사수 겹턱방사수 수지감각수 분수구강수 부채손바닥수 지근방사수'),
 ('tower','입상체','높은갑문수 깃털장각수 수직악수 우산눈수 장관탑수 막주머니장각수 분지탑수'),
 ('saddle','교각체','쌍교각갑수 현수깃수 다악교각수 감각수목수 현수여과수 지붕막수 지근안장수'),
 ('mantle','외투체','등갑외투수 벨벳아가미수 나선악외투수 부채눈외투수 관악외투수 날개외투수 촉수외투수'),
 ('spiral','권곡체','판갑달팽이 깃촉달팽이 회전턱수 분지눈권수 나팔권수 망토권수 뿌리권수'),
 ('flat','편판체','방패가오리 빗아가미판수 판악수 부채촉판수 원반흡구수 접막판수 분지판수'),
 ('chain','연쇄체','갑절연쇄충 깃절연쇄충 관절악충 수지촉각충 마디여과충 물결막충 수근연쇄충'),
 ('bilateral','쌍낭체','등갑쌍낭수 흉깃쌍낭수 갈림악수 쌍부채눈수 이중흡관수 현수망토수 쌍지근수'),
 ('crown','관형체','전개갑관수 깃털관수 다악관수 분지촉관수 왕관여과수 꽃막관수 지근관수'),
 ('amphora','항아리체','골갑항아리수 깃아가미항수 측악항수 촉각화병수 목긴여과수 돛항아리수 근족항수'),
 ('ribbon','대상체','갑띠활주수 깃띠활주수 톱니악띠수 감각리본수 관띠여과수 겹망토띠수 뿌리띠수'),
 ('branch','분지체','분지갑수 깃털수목수 가지악수 감각수관수 분지여과수 잎막수목수 뿌리별수'),
]
ORGAN_SYSTEMS=['armor','gills','mandibles','antennal_fans','siphons','sails','tendrils']
ORGAN_NOTES=['분절된 외피와 겹갑','넓게 펼친 깃 아가미','맞물리는 한 쌍의 관절 턱','가지 끝에 펼친 감각 부채','안팎 면이 있는 열린 여과관','몸통과 이어진 넓은 측막','말단이 갈라지는 굵은 촉지']
BODY_NOTES={
 'spindle':'목과 꼬리가 이어진 유선형 근육 몸통',
 'lobopod':'부드러운 몸마디와 낮은 엽족',
 'radial':'중앙 소화체에서 바깥으로 뻗는 방사 기관',
 'tower':'높은 몸통을 아래의 넓은 접지부가 지지',
 'saddle':'앞뒤 지지체를 연결하는 열린 등뼈 교각',
 'mantle':'두꺼운 외투 조직과 아래쪽 접지근',
 'spiral':'중앙 대사축 주위를 감는 연속 몸통',
 'flat':'낮고 넓은 판상 몸체와 가장자리 운동기관',
 'chain':'소화 마디와 관절을 잇는 연쇄 몸통',
 'bilateral':'좌우 장기낭을 잇는 굵은 신경목',
 'crown':'빈 중앙 공간을 둘러싼 살아 있는 관',
 'amphora':'수축 목과 열린 입구를 가진 항아리 몸체',
 'ribbon':'낮게 굽이치는 두꺼운 리본 몸통',
 'branch':'연결된 가지 몸통 끝마다 배치된 기관',
}
PLANT_GROUPS=[
 ('strap','영속대엽','웰위치아의 기저 성장에서 착안한 긴 접힘 잎'),
 ('pitcher','개방포충','열린 저장낭과 덮개가 연결된 포충 잎'),
 ('snap','관절포충','두 잎판이 경첩 줄기에서 마주 보는 포충엽'),
 ('sundew','점액감각','접힌 원반 잎의 테두리에 선모가 배열'),
 ('bladder','수포지엽','잘록한 목으로 이어진 저장낭과 기공'),
 ('rafflesia','기생육화','뿌리망 위의 두꺼운 꽃판과 중앙 통로'),
 ('hydnora','지하악화','짧은 지하체에서 벌어진 육질 꽃문'),
 ('bromeliad','집수관엽','중앙 물받이를 둘러싼 겹친 넓은 잎'),
 ('stilt','지주수관','기둥뿌리와 높이 든 분지 수관'),
 ('buttress','판근수목','넓은 판근이 연결된 굽은 줄기'),
 ('succulent','저수다육','줄기 옆으로 차곡차곡 붙는 두꺼운 저장엽'),
 ('caudex','비대근경','비대한 저장 줄기와 상부의 적은 수관'),
 ('fern','말림양치','마디 줄기 양옆의 접힌 잎과 말린 끝'),
 ('horsetail','윤생절경','속이 빈 마디 줄기와 층별 방사 잎'),
 ('fanpalm','분지부채','갈라진 줄기 끝에 펼쳐진 넓은 부채'),
 ('baobab','공동저장목','두꺼운 줄기와 열린 옆 대사낭'),
 ('candelabra','분지촉경','갈래마다 수직 성장하는 육질 줄기'),
 ('spiralcone','나선포엽','중앙축을 둘러싸고 엇갈려 붙는 포엽'),
 ('floating_roots','현수근엽','상부 잎받침에서 아래로 이어진 뿌리 실타래'),
 ('basket','편조근관','굵은 뿌리들이 만든 열린 성장 바구니'),
 ('umbrella','차양수관','층별로 열린 우산 잎과 중앙 지지 줄기'),
 ('shield','방패엽','비대칭 줄기 끝의 넓은 방패 모양 잎'),
 ('corkscrew','권곡엽','중앙 줄기를 감싸는 두꺼운 나선 잎'),
 ('rattlepod','현수협과','곡선 가지에서 매달린 열린 씨앗 꼬투리'),
 ('orchid','입체순판','수관 끝에서 방향을 달리하는 꽃받침과 입술판'),
 ('lithops','균열석엽','두꺼운 쌍엽 사이의 열린 성장 틈'),
 ('stagfern','분지엽각','끝이 갈라지는 넓고 두꺼운 뿔 모양 잎'),
 ('fenestrate','투공엽','잎살과 지지맥이 둘러싼 열린 투공판'),
]
MICROBE_GROUPS=[
 ('stromatolite','층적생물막','퇴적된 파문형 생물막과 열린 내부 수로'),
 ('filament','교직사상군','땅에 접한 굵은 사상체의 교차 그물'),
 ('rosette','방사여과군','중앙 습윤부를 둘러싼 방사형 열린 수로'),
 ('siphon','분지흡관군','공동 기질 위에서 갈라지는 개방 흡관'),
 ('vesicle','다낭기포군','좁은 목으로 이어진 여러 대사낭'),
 ('honeycomb','육실생물막','각진 빈 방을 연결하는 두꺼운 막벽'),
 ('diatom','다공격판군','굵은 지지맥과 열린 구획을 가진 판상 군락'),
 ('dendrite','수지생물막','기질 표면에서 가지처럼 분기하는 군체'),
 ('chimney','대사굴뚝군','다수의 열린 대사 굴뚝과 공통 기반'),
 ('fold','습윤습곡군','서로 겹친 넓은 주름 생물막'),
 ('lace','격공아치군','기질에 붙은 열린 아치와 연결 생물막'),
 ('pustule','융합결절군','분열 경계가 보이는 연결된 육질 결절'),
 ('scroll','권곡피막군','안팎 면이 보이는 말린 두꺼운 생물막'),
 ('tubule','환상세관군','낮은 환형 세관과 말단 여과구'),
]
TOPOLOGIES=['직렬','만곡','분기','쌍열','방사']
TAXON_PREFIX=['곧은','굽은','갈래','쌍줄','둘레']
COUNTS=['세','네','다섯','여섯','일곱','여덟','아홉','열','열한','열두']
SOURCES={
 'animal':['https://www.mbari.org/education/animals-of-the-deep/','https://ocean.si.edu/holding-tank/images-hide/siphonophores','https://www.nhm.ac.uk/our-science/services/collections/zoology/small-invertebrate-phyla.html'],
 'plant':['https://powo.science.kew.org/taxon/urn:lsid:ipni.org:names:383591-1/general-information','https://www.kew.org/plants/venus-flytrap','https://www.kew.org/plants/rafflesia-arnoldi'],
 'microbe':['https://naturalhistory.si.edu/education/teaching-resources/life-science/early-life-earth-animal-origins','https://astrobiology.nasa.gov/news/the-three-domains-of-life/'],
}

def groups():
    result=[]
    for body,label,names in ANIMAL_GROUPS:
        for organ,name in zip(ORGAN_SYSTEMS,names.split()):
            result.append({'family':f'biota_{body}_{organ}','family_name':name,'category':'animal','construction':body,'organ_system':organ,'structure_note':BODY_NOTES[body]+'·'+ORGAN_NOTES[ORGAN_SYSTEMS.index(organ)]})
    for category,rows in [('plant',PLANT_GROUPS),('microbe',MICROBE_GROUPS)]:
        for construction,name,note in rows:result.append({'family':f'biota_{category}_{construction}','family_name':name,'category':category,'construction':construction,'organ_system':'growth','structure_note':note})
    assert len(result)==140
    return result

def recipes():
    result=[]
    for fi,group in enumerate(groups()):
        for v in range(50):
            topology=v//10;organs=3+v%10
            row=dict(group)
            row.update({'id':f"{group['family']}_{v+1:02d}",'name':TAXON_PREFIX[topology]+COUNTS[v%10]+'마디'+group['family_name'],
              'collection':COLLECTION,'environment':ENVIRONMENTS[(fi*3+v)%7],
              'anatomy':v,'morphology':v,'attack':'none','eye_count':0,
              'anatomy_note':group['structure_note']+' / '+TOPOLOGIES[topology]+f' 배열·주요 기관 {organs}개',
              'representation':'visible_microbial_colony' if group['category']=='microbe' else ('rooted_plant' if group['category']=='plant' else 'ground_animal'),
              'locomotion_medium':'ground','motion_profile':['compress','sway','flex','pulse','spiral'][topology],
              'sensory_type':group['organ_system'],'habitat_note':'별도 제작한 가상 지상 기본형. 실제 기후·지형·공간 판정 이후 자연 배치.',
              'body_plan':{'topology':topology,'radial_count':organs,'limb_count':2*(2+v%4),'width':[.92,1.05,1.17,.85,1.10][topology],
                           'height':[1,.92,1.10,1.25,.82][topology],'branch_mode':topology},
              'variant_count':20,'spawn_enabled':False,'reference_sources':SOURCES[group['category']]})
            adaptation,environment,term,note=ADAPTATIONS[(fi*3+v)%len(ADAPTATIONS)]
            aerial=(v in [8,17,26,35,44] and ((group['category']=='animal' and group['construction'] in ['mantle','radial','flat','bilateral','amphora','crown','branch']) or group['category']=='microbe' or (group['category']=='plant' and group['construction'] in ['bladder','umbrella','floating_roots','basket'])))
            if aerial:
                adaptation=GAS_ARCHETYPES[(fi+v)%6];environment='gas_cloud';term='운해';note='고체 발판 없이 떠 있는 부력낭·평형막·현수 여과기관의 가상 대기층 생태'
                row['locomotion_medium']='atmosphere';row['representation']='aerial_colony' if group['category']=='microbe' else 'atmospheric_floater'
                row['reference_sources']=row['reference_sources']+['https://ntrs.nasa.gov/citations/19770038871']
            elif v%9==7:
                environment='cave';term='암중';note='작은 시각기관·길어진 촉각·기질 부착기관의 지하 생태'
            flight_variants=(FLIGHT_ANATOMIES-{0})|{4} if group['organ_system']=='armor' else FLIGHT_ANATOMIES
            if group['construction']=='bilateral' and v in flight_variants:
                adaptation=FLIGHT_HABITATS[(fi+v)%len(FLIGHT_HABITATS)]
                _,environment,term,_=next(a for a in ADAPTATIONS if a[0]==adaptation)
                wing_style=['broad','scythe','tandem','membrane','fan'][topology]
                wing_label=['넓은깃','낫날깃','겹날개','비막','부채꼬리'][topology]
                note='어깨·팔꿈치·손목이 연결된 '+wing_label+' 비행기관·흉골 용골·접이 발과 조향 꼬리'
                row.update(construction='avian',locomotion_medium='surface_air',representation='winged_animal',motion_profile='flight',eye_count=2)
                row['name']=COUNTS[v%10]+'깃'+wing_label+group['family_name'].replace('쌍낭수','새').replace('쌍지근수','갈래꼬리새')
                row['anatomy_note']=note+' · '+group['structure_note']
                row['flight']={'version':1,'wing_style':wing_style,'wing_pairs':2 if wing_style=='tandem' else 1,'primary_feathers':organs,'minimum_pressure_kpa':50.0,'flap_hz':[1.5,2.0,1.7,1.25,1.4][topology],'patrol_radius':4.5+topology*.5,'cruise_height':4.0+topology*.35,'cycle_seconds':48.0,'rest_seconds':12.0,'transition_seconds':5.0}
                row['reference_sources']=row['reference_sources']+['https://academy.allaboutbirds.org/feathers-article/','https://gardens.si.edu/exhibitions/traveling/habitat/different-wings-for-different-birds/']
                row['recipe_revision']='avian-1'
            row['environment']=environment;row['adaptation_id']=adaptation;row['native_archetypes']=[adaptation]
            row['name']=term+row['name'];row['adaptation_note']=note
            row['habitat_note']=note+' · 행성 기후와 실제 서식 층을 별도 검사한다.'
            replacement(row,fi//7,fi%7,ADAPTATIONS)
            if row['category']=='plant' and row['construction']=='spiralcone':row['recipe_revision']='bract-stem-1'
            result.append(row)
    assert len(result)==7000 and len({r['name'] for r in result})==7000
    return result

if __name__=='__main__':
    path=ROOT/'우주-비즈니스/data/bestiary/biota_recipes.json'
    path.write_text(json.dumps({'version':1,'collection':COLLECTION,'species_count':7000,'structural_groups':140,'species':recipes()},ensure_ascii=False,indent=2)+'\n')
    print(path)
