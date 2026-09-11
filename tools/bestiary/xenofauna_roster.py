"""300 authored anatomical recipes; runtime seeds select recipes, never assemble anatomy."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
COLLECTION = 'xenofauna-300'
# A family is an anatomical construction, not a colourway. Ten named species each
# change the number, arrangement and junction of the main load-bearing organs.
FAMILIES = [
 ('torus_loom','환공직조류','몸통 가운데가 뚫린 근육 고리와 안쪽 여과실','flex',
  '외고리직조수 쌍환직조수 삼문직조수 넓은문직조수 오공직조수 비틀린환수 갈라진환수 관문직조수 교차환수 십자직조수'),
 ('double_vault','쌍궁보행류','나란한 두 등뼈 아치 아래에 매달린 신경기관','sway',
  '쌍궁낙수 삼궁낙수 갈퀴궁수 낮은궁수 높은궁수 엇궁낙수 겹궁낙수 사다리궁수 천막궁수 끝갈림궁수'),
 ('pentapalm','방사수장류','머리 없이 손바닥처럼 갈라진 방사형 몸통과 손끝 입','pulse',
  '세손바닥수 네손바닥수 다섯손바닥수 여섯손바닥수 일곱손바닥수 갈래손수 넓적손수 긴손등수 이중손수 왕관손수'),
 ('walking_calyx','개화구강류','꽃받침 같은 두꺼운 구강판이 벌어지는 보행 동물','bloom',
  '삼판입수 사판입수 오판입수 육판입수 칠판입수 접시입수 주머니입수 겹꽃입수 톱니입수 속꽃입수'),
 ('saddle_bridge','안장교각류','앞뒤 몸통 사이가 비어 있는 안장 등뼈와 복부 현수기관','sway',
  '낮은안장수 쌍봉안장수 삼봉안장수 긴안장수 넓은안장수 갈림안장수 겹다리안장수 문형안장수 뿔안장수 높은안장수'),
 ('gyre_tower','나선탑류','속이 빈 나선형 몸통을 다리와 대사낭이 지탱','spiral',
  '한바퀴탑수 두바퀴탑수 세바퀴탑수 낮은탑수 높은탑수 벌어진탑수 쌍나선탑수 계단탑수 갈래탑수 왕관탑수'),
 ('twin_moons','이중낭체류','떨어진 두 장기낭이 굵은 신경목으로 연결된 비대칭 체형','pulse',
  '수평쌍낭수 수직쌍낭수 엇갈린쌍낭수 작은달낭수 큰달낭수 세달낭수 분지낭수 현수낭수 나란한낭수 고리낭수'),
 ('accordion_shell','주름갑체류','중심 축을 따라 압축되는 큰 외골격 주름과 측면 발','compress',
  '삼주름갑수 사주름갑수 오주름갑수 육주름갑수 칠주름갑수 벌어진갑수 높은갑수 낮은갑수 갈퀴갑수 겹주름갑수'),
 ('veil_antler','막각보행류','넓은 감각막을 뿔 사이에 편 머리 없는 저상 보행체','sway',
  '두막각수 세막각수 네막각수 부채막각수 우산막각수 갈림막각수 긴막각수 쌍막각수 접힌막각수 관막각수'),
 ('rib_sled','늑골활주류','열린 갈비뼈 우리와 바닥을 짚는 굵은 양측 주행근','compress',
  '삼늑활주수 사늑활주수 오늑활주수 육늑활주수 칠늑활주수 긴늑활주수 벌어진늑수 낮은늑수 겹늑활주수 갈고리늑수'),
 ('crown_anchor','관묘류','납작한 복판과 위로 휘어 맞물리는 닻 모양 돌기','flex',
  '삼묘관수 사묘관수 오묘관수 육묘관수 칠묘관수 벌어진관수 옆관수 이중관수 긴닻관수 뿔닻관수'),
 ('inverted_fan','역선체류','한쪽에 치우친 부채 몸통과 반대쪽의 접지 다발','bloom',
  '삼살역선수 사살역선수 오살역선수 육살역선수 칠살역선수 쌍부채수 접힌역선수 넓은역선수 갈림역선수 관부채수'),
 ('spiral_hinge','와선경첩류','좌우 나선 디스크가 중앙 관절을 사이에 두고 벌어짐','flex',
  '홑와선수 쌍와선수 삼와선수 열린와선수 닫힌와선수 엇와선수 긴축와선수 삼축와선수 톱니와선수 관와선수'),
 ('lattice_beast','격자골수류','살덩어리 대신 빈 공간을 둘러싼 격자 골격과 마디 장기','sway',
  '삼각격자수 사각격자수 오각격자수 육각격자수 칠각격자수 쌍층격자수 탑격자수 옆격자수 분지격자수 관격자수'),
 ('funnel_stilt','누두장각류','큰 깔때기 몸통의 바깥 벽에서 바로 이어지는 긴 다리','bloom',
  '삼각누두수 사각누두수 오각누두수 육각누두수 칠각누두수 이중누두수 낮은누두수 긴목누두수 분지누두수 좁은누두수'),
 ('crescent_maw','월아구강류','초승달 모양 몸통의 열린 두 끝이 서로 마주 보는 입','flex',
  '가는월아수 넓은월아수 쌍월아수 삼월아수 깊은월아수 벌어진월아수 갈림월아수 옆월아수 장축월아수 뿔월아수'),
 ('radial_mill','방사노체류','중앙 배를 둘러싼 두꺼운 노 모양 사지와 말단 흡착판','spiral',
  '삼노보행수 사노보행수 오노보행수 육노보행수 칠노보행수 쌍노보행수 긴노보행수 넓은노수 갈래노수 겹노보행수'),
 ('knuckle_chain','관절연쇄류','개별 장기 마디가 큰 아치형 사슬을 만드는 몸통','compress',
  '삼절연쇄수 사절연쇄수 오절연쇄수 육절연쇄수 칠절연쇄수 갈림연쇄수 쌍연쇄수 높이연쇄수 낮은연쇄수 다환연쇄수'),
 ('pendulum_grazer','현수섭식류','골격 아치 안에서 식도와 입이 진자처럼 매달림','sway',
  '외추섭식수 쌍추섭식수 삼추섭식수 사추섭식수 오추섭식수 긴추섭식수 넓은추수 엇추섭식수 분지추수 관추섭식수'),
 ('split_keel','쌍용골류','두 개의 긴 몸통이 가로 근육으로 결합된 지상 동물','compress',
  '짧은쌍골수 긴쌍골수 삼교쌍골수 사교쌍골수 오교쌍골수 갈래쌍골수 벌어진쌍골수 엇쌍골수 세용골수 날개골수'),
 ('petal_mantis','판엽절지류','넓은 판 모양 몸마디가 관절마다 접히는 절지형','bloom',
  '삼판절지수 사판절지수 오판절지수 육판절지수 칠판절지수 겹판절지수 갈래판수 긴판절지수 둥근판수 뿔판절지수'),
 ('cup_colony','보행다완류','여러 개의 큰 입그릇이 하나의 이동성 몸통을 공유','pulse',
  '삼완군수 사완군수 오완군수 육완군수 칠완군수 층완군수 고리완수 갈래완수 긴목완수 겹완군수'),
 ('corkscrew_spine','횡선척추류','수평으로 감긴 나선 척추와 각 고리의 독립 접지기관','spiral',
  '홑선척수 쌍선척수 삼선척수 사선척수 오선척수 넓은선척수 갈림선척수 낮은선척수 겹선척수 뿔선척수'),
 ('umbrella_clutch','산개포옹류','층층이 겹친 우산형 장기판 아래에 모인 집게 다발','bloom',
  '홑산개수 쌍산개수 삼산개수 넓은산개수 높은산개수 갈림산개수 접힌산개수 관산개수 층층산개수 역산개수'),
 ('mirror_fork','분기대칭류','중심에서 두 갈래로 나뉜 몸통 끝에 서로 다른 감각기관','flex',
  '쌍갈래수 삼갈래수 사갈래수 넓은갈래수 좁은갈래수 엇갈래수 관갈래수 이중갈래수 긴갈래수 손갈래수'),
 ('quill_amphora','유공호체류','항아리형 외피의 큰 구멍과 안쪽을 보호하는 곡선 가시','pulse',
  '삼공호수 사공호수 오공호수 육공호수 칠공호수 쌍층호수 낮은호수 높은호수 갈림호수 관호수'),
 ('braid_crawler','편조보행류','서로 꼬인 여러 근육줄기 사이로 장기가 드러나는 체형','spiral',
  '두줄편조수 세줄편조수 네줄편조수 다섯줄편조수 여섯줄편조수 벌어진편조수 갈래편조수 긴편조수 이중편조수 관편조수'),
 ('hinge_book','개폐서판류','책장처럼 벌어지는 한 쌍의 골격판과 안쪽 감각엽','bloom',
  '쌍서판수 삼서판수 사서판수 넓은서판수 높은서판수 갈림서판수 겹서판수 옆서판수 빗살서판수 관서판수'),
 ('offset_halo','편심환체류','서로 다른 축의 고리 장기가 편심 관절로 맞물림','sway',
  '쌍편심환수 삼편심환수 사편심환수 낮은편심수 높은편심수 엇편심환수 열린편심수 사슬편심수 갈림편심수 관편심환수'),
 ('root_octant','분지근체류','중앙 머리 없이 굵게 분지하는 몸통의 끝이 발과 입을 겸함','flex',
  '삼분지근수 사분지근수 오분지근수 육분지근수 칠분지근수 쌍층분지수 긴분지근수 낮은분지수 갈래근수 관분지근수'),
]

ENVIRONMENTS = ['basalt','arid','cold','cave','temperate','crystal','thermal']
SENSORS = ['피부 진동공','분산 감광점','깊은 감각구','빛을 모으는 틈','방사 화학수용기',
           '주름형 압력막','말단 감각패드','이중 감각고리','빗살 감각엽','분지 촉각수염']
TOPOLOGIES = ['삼방 열린 골격','사방 연결 골격','오방 분절 골격','낮고 넓은 육방 골격',
              '높고 좁은 칠방 골격','비대칭 분기 골격','이중 배열 골격','편심 장축 골격',
              '교차 연결 골격','다층 방사 골격']

def recipes():
    rows=[]
    for fi,(family,label,anatomy,motion,names) in enumerate(FAMILIES):
        for v,name in enumerate(names.split()):
            env=ENVIRONMENTS[(fi*3+v)%len(ENVIRONMENTS)]
            rows.append({'id':f'bio_{family}_{v+1:02d}', 'name':name, 'family':family,
                'family_name':label,'category':'animal','collection':COLLECTION,
                'environment':env,'morphology':v,'anatomy':v,'attack':'none',
                'anatomy_note':anatomy+' / '+TOPOLOGIES[v],
                'sensory_type':SENSORS[v],'eye_count':0 if v%3==0 else 2+v%5,
                'motion_profile':motion,'locomotion_medium':'ground',
                'body_plan':{'radial_count':[3,4,5,6,7,3,4,5,6,8][v],
                             'limb_count':[3,4,5,6,7,4,6,4,8,6][v],
                             'branch_mode':v,'width':[1,.85,1.05,1.3,.72,1.15,.95,1.1,1.08,1][v],
                             'height':[1,1.12,.93,.73,1.4,.96,1.05,1.2,.88,1.16][v]},
                'variant_count':20,'spawn_enabled':False,
                'habitat_note':'준비한 지상 체형. 서식 기후·지지면·공간 조건을 통과한 위치에만 출현.'})
    assert len(rows)==300 and len({r['name'] for r in rows})==300
    return rows

if __name__=='__main__':
    path=ROOT/'우주-비즈니스/data/bestiary/xenofauna_recipes.json'
    path.write_text(json.dumps({'version':1,'collection':COLLECTION,'species_count':300,
        'body_plan_count':30,'counting':'고유 구조 모델 300개. 색·크기 외형은 별도 집계.',
        'species':recipes()},ensure_ascii=False,indent=2)+'\n')
    print(path)
