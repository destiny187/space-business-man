"""Replace the two middle entries of 98 animal groups, without inflating counts.

28 readable anatomical silhouettes × 7 functional organ lineages = 196 replacements.
The existing 1,000 published forms and the other 6,804 new recipes are untouched.
"""
KINDS=[
 ('cervid','분지뿔초식수','proboscid','갈림코거수'),
 ('canid','감각깃추적수','felid','갈고리발잠행수'),
 ('chelonian','열판등딱지수','crocodilian','톱등장악수'),
 ('giraffoid','관목장경수','camelid','쌍저수등수'),
 ('rhinocerid','도끼뿔중갑수','bovid','나선뿔들소수'),
 ('anuran','저음낭도약수','monotreme','전기부리수'),
 ('pangolin','잎비늘개미수','armadillo','절갑굴착수'),
 ('gekkonid','부채발암벽수','skink','쐐기머리유선수'),
 ('macropod','삼점꼬리도약수','lagomorph','갈래귀뜀수'),
 ('wader','장각여과새','owl','원반얼굴밤새'),
 ('arachnid','쌍복안거미수','scorpion','등활독침수'),
 ('crab','편갑집게수','hermit','나선등짐집게수'),
 ('mustelid','긴허리굴수','serpent','감각후드뱀수'),
 ('mantid','접이낫팔수','beetle','분할등날개수'),
]
GROUND_KINDS={name for row in KINDS for name in row[::2]}-{'wader','owl'}
LINEAGES=['겹갑','깃여과','쌍턱','부채감각','열린흡관','측막','갈래촉지']
HABITATS={
 'cervid':['continental','tundra'],'proboscid':['salt','ochre'],
 'canid':['tundra','continental'],'felid':['sedimentary','continental'],
 'chelonian':['volcanic','crystalline'],'crocodilian':['sedimentary','ochre'],
 'giraffoid':['continental','salt'],'camelid':['oxidized','salt'],
 'rhinocerid':['volcanic','cratered'],'bovid':['tundra','continental'],
 'anuran':['continental','sedimentary'],'monotreme':['continental','sedimentary'],
 'pangolin':['crystalline','sedimentary'],'armadillo':['oxidized','cratered'],
 'gekkonid':['ochre','crystalline'],'skink':['salt','oxidized'],
 'macropod':['salt','continental'],'lagomorph':['tundra','continental'],
 'wader':['sedimentary','continental'],'owl':['tundra','continental'],
 'arachnid':['cratered','crystalline'],'scorpion':['volcanic','oxidized'],
 'crab':['salt','sedimentary'],'hermit':['crystalline','salt'],
 'mustelid':['tundra','sedimentary'],'serpent':['ochre','sedimentary'],
 'mantid':['continental','crystalline'],'beetle':['volcanic','alkaline'],
}
NOTES={
 'cervid':'높은 네 갈래굽 다리·세운 목·분지 여과뿔',
 'proboscid':'기둥 다리·넓은 귀막·세 관절의 갈림코와 측방 엄니',
 'canid':'발가락으로 딛는 네 다리·긴 주둥이·깃꼬리·삼각 감각귀',
 'felid':'낮은 어깨와 긴 허리·짧은 얼굴·수납 갈고리발·긴 조향꼬리',
 'chelonian':'둥근 등딱지·접히는 목·짧은 사지·겹친 차열 판',
 'crocodilian':'긴 평면 주둥이·낮게 벌어진 네 다리·톱니 등과 장절 꼬리',
 'giraffoid':'길게 연결된 목뼈·높은 머리·가는 장각·관목 모양 감각뿔',
 'camelid':'높은 쌍저수 등·굽은 긴 목·넓은 모래 발바닥·폐쇄 콧구멍',
 'rhinocerid':'앞으로 치우친 큰 어깨·짧은 기둥다리·도끼 모양 차열 뿔',
 'bovid':'넓은 흉부·낮은 머리·옆으로 감기는 뿔·단열 목주름',
 'anuran':'넓은 얼굴·압축 뒷다리·긴 도약 발·양쪽 공명낭',
 'monotreme':'납작한 감각 부리·물갈퀴 사지·넓은 노 모양 꼬리',
 'pangolin':'겹친 잎비늘·가늘어진 흡입 주둥이·긴 중량 꼬리·굴착 발톱',
 'armadillo':'띠로 나뉜 돔 등갑·짧은 굴착다리·관절 코·가느다란 고리꼬리',
 'gekkonid':'큰 측안·옆으로 벌어지는 다리·세 갈래 넓은 접착 발·굵은 꼬리',
 'skink':'낮은 쐐기 머리·연속된 긴 유선 몸통·매우 짧은 다리·긴 첨미',
 'macropod':'세운 흉부·작은 앞팔·굵은 뒷넓적다리·긴 도약발·접지 꼬리',
 'lagomorph':'굽힌 뒷다리·긴 귀의 갈라진 열교환 면·짧은 꼬리',
 'wader':'긴 S자 목·긴 착지 다리·가는 탐침 부리·길고 가는 비행깃',
 'owl':'넓은 원반 얼굴·전면 눈·짧은 갈고리 부리·넓은 저속 날개',
 'arachnid':'뚜렷한 머리가슴과 뒤 배·네 쌍의 세 마디 보행지·큰 전면 눈',
 'scorpion':'작은 몸통·앞 집게·네 쌍의 보행지·등 위로 감긴 관절 독침꼬리',
 'crab':'넓고 낮은 등갑·측방 보행지·서로 크기가 다른 집게·자루 눈',
 'hermit':'편심 나선 등짐과 연한 배·앞으로 모인 보행지·입구 방패 집게',
 'mustelid':'긴 유연 허리·짧은 네 다리·둥근 귀·좁은 굴 탐색 머리',
 'serpent':'다리 없는 연속 S자 근육몸통·긴 축 골격·좌우 감각 후드',
 'mantid':'높은 가슴·삼각 머리·접히는 낫 앞팔·네 지지다리·긴 뒤 배',
 'beetle':'머리·가슴·배의 세 구획·세 쌍 보행지·열리는 두 장의 등날개',
}
REFERENCES=[
 'https://animals.sandiegozoo.org/animals/kangaroo-and-wallaby',
 'https://australian.museum/learn/animals/spiders/spider-structure/',
 'https://www.nhm.ac.uk/discover/news/2020/april/collections-showing-how-pangolin-populations-have-shrunk.html',
]

def replacement(row,body_index,organ_index,adaptations):
    if row['category']!='animal' or row['anatomy'] not in (24,25):return
    offset=(row['anatomy']-24)*2;entry=KINDS[body_index]
    kind,label=entry[offset:offset+2]
    adaptation=HABITATS[kind][organ_index%2]
    _,environment,term,note=next(a for a in adaptations if a[0]==adaptation)
    row.update(anatomical_type=kind,recipe_revision='midpoint-5-orbits',
        construction='avian' if kind in ('wader','owl') else kind,
        name=term+LINEAGES[organ_index]+label,structure_note=NOTES[kind],
        family_name=label,
        anatomy_note=NOTES[kind]+' · '+LINEAGES[organ_index]+' 기관 계통',
        environment=environment,adaptation_id=adaptation,native_archetypes=[adaptation],
        adaptation_note=note,habitat_note=note+' · 실제 행성 기후와 서식 층 판정을 유지한다.',
        replacement={'version':1,'slot':row['anatomy']+1,'reason':'중간 유사 형태의 큰 체형과 관절 구조 교체'},
        eye_count=6 if kind=='arachnid' else 2)
    if kind not in {'wader','owl','arachnid','scorpion','crab','hermit','mantid','beetle'}:
        row['recipe_revision']='midpoint-6-details'
    row['ocular_design']={'version':1,'anatomical_profile':kind,'geometry':'faceted-compound' if kind in ('crab','hermit','mantid','beetle') else ('simple-ocelli' if kind in ('arachnid','scorpion') else 'embedded-lens-with-authored-lids'),'emissive':False}
    row['reference_sources']=row['reference_sources']+REFERENCES
    row['body_plan']=dict(row['body_plan'],anatomical_type=kind,
        limb_count={'arachnid':8,'scorpion':8,'crab':8,'hermit':6,'mantid':6,'beetle':6,'serpent':0,'wader':2,'owl':2}.get(kind,4),
        radial_count=3 if kind in ('wader','owl') or row['organ_system'] not in ('mandibles','sails') else 2)
    if kind in ('wader','owl'):
        row['review_front']='+Y'
        row['body_plan']['wing_count']=2
        row['flight'].update(wing_pairs=1,wing_style='scythe' if kind=='wader' else 'broad',primary_feathers=7+organ_index,
            flap_hz=1.35 if kind=='wader' else 1.8)
    else:
        row.update(locomotion_medium='ground',representation='ground_animal',motion_profile='anatomical')
        row.pop('flight',None)
