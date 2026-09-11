"""100 prepared alien plants and visible microbial colonies, excluding colour/size variants."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
COLLECTION='xenoflora-100'
ENVIRONMENTS=['basalt','arid','cold','cave','temperate','crystal','thermal']
FAMILIES=[
 ('loop_frond','반전환엽류','plant','줄기에서 나와 뒤집히며 닫히는 두꺼운 띠 잎','flex','홑환리본초 쌍환리본초 삼환리본초 교차리본초 관환리본초'),
 ('lantern_root','현수근낭류','plant','아치형 뿌리 아래에 매달린 낭과 위쪽의 집수 잎','sway','한등뿌리수 쌍등뿌리수 삼등뿌리수 분지등수 왕관등수'),
 ('spiral_cup_tree','나선배상류','plant','나선 줄기의 서로 다른 높이에 열린 집수 잎이 자리함','spiral','세잔나무 네잔나무 다섯잔나무 엇잔나무 관잔나무'),
 ('mirror_reed','대향막경류','plant','갈라진 줄기의 좌우에 마주 보는 두꺼운 부채막','sway','쌍막갈대 네막갈대 여섯막갈대 엇막갈대 관막갈대'),
 ('lattice_orchid','격자화방류','plant','속이 빈 꽃받침 골격과 모서리에 붙은 넓은 꽃잎','bloom','삼각공란 사각공란 오각공란 이층공란 관격공란'),
 ('bell_vine','현수종등류','plant','기어 올라간 굽은 덩굴의 아래로 처진 열린 종형 잎','sway','세종덩굴 네종덩굴 다섯종덩굴 엇종덩굴 관종덩굴'),
 ('folded_crown','접선관엽류','plant','방사형 줄기 위에 접힌 부채 주름과 겹쳐진 잎집','bloom','삼주름관초 사주름관초 오주름관초 겹주름관초 나선주름관초'),
 ('bladder_cactus','공낭연경류','plant','서로 떨어진 물 저장 낭을 줄기와 살아 있는 가교가 연결','pulse','삼낭선인 사낭선인 오낭선인 엇낭선인 관낭선인'),
 ('comb_tendril','빗살촉엽류','plant','길게 휜 줄기 양옆에 교대로 달린 숟가락형 잎','flex','세빗촉초 네빗촉초 다섯빗촉초 쌍빗촉초 관빗촉초'),
 ('eclipse_bloom','환공차광류','plant','큰 구멍이 있는 꽃판 둘레에서 안팎으로 접히는 빛 수집 잎','bloom','단환일식화 협환일식화 쌍환일식화 겹문일식화 관문일식화'),
 ('coral_scroll','분지권엽류','plant','고리로 말린 끝잎을 가진 넓게 분기하는 산호형 줄기','flex','삼권분지초 사권분지초 오권분지초 겹권분지초 관권분지초'),
 ('nested_pod','중첩개협류','plant','속이 드러나는 꼬투리 안에 더 작은 꼬투리와 씨방이 중첩','bloom','이중협초 삼중협초 사중협초 엇협초 관협초'),
 ('siphon_mosaic','흡관모자이크군','microbe','넓은 점액 기질에서 크기가 다른 열린 대사관이 반복되는 군락','pulse','오관모자이크군 육관모자이크군 칠관모자이크군 이층흡관군 나선흡관군'),
 ('vesicle_raft','기포뗏막군','microbe','끈끈한 생물막에 다수의 가스 저장 소낭이 연결된 군락','pulse','사포뗏막군 오포뗏막군 육포뗏막군 겹포뗏막군 관포뗏막군'),
 ('quorum_spires','천공첨탑군','microbe','다수의 통기 구멍과 연결 기저막을 가진 화학 대사 탑 군락','compress','두탑천공군 세탑천공군 네탑천공군 엇탑천공군 관탑천공군'),
 ('channel_rosette','유로장미군','microbe','낮은 방사형 유로와 말린 끝단이 모이는 대사막 군락','pulse','삼로장미군 사로장미군 오로장미군 겹로장미군 나선유로군'),
 ('braided_film','편조생물막군','microbe','지지점 사이로 두꺼운 막이 뒤틀려 엮인 대형 미생물 군락','flex','두겹편막군 세겹편막군 네겹편막군 교차편막군 관편막군'),
 ('prismatic_pustule','다낭광막군','microbe','기질 위의 타원 소낭을 유색 격막이 나누고 연결하는 군락','pulse','네낭광막군 다섯낭광막군 여섯낭광막군 이중광막군 관낭광막군'),
 ('lace_colony','투공망막군','microbe','큰 통로가 관통하는 돔형 생물막과 다공성 기저층','compress','삼문망막군 사문망막군 오문망막군 겹문망막군 관문망막군'),
 ('tidal_stromat','층상파문군','microbe','수분을 모으는 주름진 층과 얕은 중앙 분지가 쌓인 군락','pulse','세층파문군 네층파문군 다섯층파문군 쌍분지파문군 관층파문군'),
]
TOPOLOGIES=['기초 기관 배열','기관 추가·좁고 높은 외곽','다중 기관·넓은 외곽','연결 수 증가·상하 전개','조밀한 기관·높은 외곽']
def recipes():
    rows=[]
    for fi,(family,label,category,note,motion,names) in enumerate(FAMILIES):
        for v,name in enumerate(names.split()):
            rows.append({'id':f'bio_{family}_{v+1:02d}','name':name,'family':family,'family_name':label,
                'category':category,'collection':COLLECTION,'environment':ENVIRONMENTS[(fi*2+v)%7],
                'morphology':v,'anatomy':v,'attack':'none','eye_count':0,
                'sensory_type':'분산된 광·수분 반응 조직' if category=='plant' else '군락의 화학 농도 반응',
                'anatomy_note':note+' / '+TOPOLOGIES[v], 'motion_profile':motion,'locomotion_medium':'ground',
                'body_plan':{'radial_count':[3,4,5,6,8][v],'width':[1,.86,1.12,1.05,.90][v],
                             'height':[1,1.2,.92,1.12,1.32][v],'branch_mode':v},
                'variant_count':20,'spawn_enabled':False,
                'representation':'rooted_plant' if category=='plant' else 'visible_microbial_colony',
                'habitat_note':'고정 지지면의 가상 식물. 환경에 맞는 현지 계통으로 출현.' if category=='plant' else '단일 세포 확대물이 아닌 눈에 보이는 미생물 군락·생물막.'})
    assert len(rows)==100 and len({r['name'] for r in rows})==100
    return rows
if __name__=='__main__':
    (ROOT/'우주-비즈니스/data/bestiary/xenoflora_recipes.json').write_text(json.dumps(
        {'version':1,'collection':COLLECTION,'species_count':100,'plants':60,'microbes':40,'structure_groups':20,'species':recipes()},ensure_ascii=False,indent=2)+'\n')
