# 이형 생물 추가 100개 — 감각기관·해부 구조 다양화

2026-09-06 사용자는 기존 생물의 눈이 너무 비슷하다는 피드백과 함께 독창적이고 그로테스크한 기본 모델 100개 추가를 요청했다. 기존 500개를 유지하고 총 600개로 확장한다. [생물 렌더링 공통 규칙](08-bestiary-rendering.md)과 [INK v1](06-rendering-quality-standard.md)을 따른다. 공격하는 추가 동물에도 동작과 효과를 포함한다.

## 제작 구성

추가 100개는 새 구조군 10개에 각각 해부 형상 10개를 둔다. 늑골·입·다리·막·감각 가지의 수와 배치, 비대칭, 체절과 비례를 형상에 직접 반영한다. 색상만 바꾼 파일을 기본 모델에 합산하지 않는다. 각 모델은 환경에 연결한 팔레트 5개와 크기 4개로 외형 프로필 20개를 제공한다. 추가 프로필 2,000개, 전체 12,000개이며 독립적인 생물 종 수를 의미하지 않는다.

| 구조군 | 감각기관과 형태 | 공격 표현 |
| --- | --- | --- |
| [공명늑골체](media/bestiary/boards/blind_harp.jpg) | 눈 없음, 속이 빈 늑골과 장력 섬유, 낮은 다리 | 없음 |
| [나선구강체](media/bestiary/boards/spiral_maw.jpg) | 눈 없음, 치환과 말린 방사형 촉수 | 구강 수축·물기 |
| [삼각종보행체](media/bestiary/boards/tripod_bell.jpg) | 눈 없음, 세 다리에 매달린 종과 압력 주름 | 들어 올려 내려치기 |
| [유막부유체](media/bestiary/boards/lantern_sail.jpg) | 눈 없음, 세로 막과 전기 감각 필라멘트 | 없음 |
| [수지다안체](media/bestiary/boards/eye_orchard.jpg) | 5~14개의 비대칭 가지 눈, 긴 세로 동공 | 구강 분사 |
| [편측집게체](media/bestiary/boards/asym_pincer.jpg) | 한쪽 단안의 동심 렌즈, 거대한 한쪽 집게 | 집게 공격 |
| [주름띠군체](media/bestiary/boards/ribbon_colony.jpg) | 9~18개 안점이 체절에 분산, 접힌 띠 몸통 | 없음 |
| [창낭보행체](media/bestiary/boards/window_sac.jpg) | 벌어진 외피 사이의 단일 긴 감광 틈 | 구강 분사 |
| [복안관추적체](media/bestiary/boards/crown_stalker.jpg) | 여러 다면 렌즈가 붙은 하나의 복안면, 방사형 다리 | 낫형 앞다리 베기 |
| [분지다구체](media/bestiary/boards/manymouth.jpg) | 여러 갈래 입, 0~4개의 불규칙 안점 | 다중 구강 수축·물기 |

무안형 42개, 단일 감각 눈/복안면 32개, 다안형 26개다. 복안관추적체의 eye_count=1은 하나의 복안 기관을 뜻하며 표면의 렌즈 소면 수와 구분한다. 추가 70개에 공격 표현이 있고 30개는 비공격형이다. 전체는 동물 400개·식생 125개·미생물 군락 75개, 공격 표현 320개다.

외계성은 빈 공간, 비대칭, 방사형 구강, 노출된 감각 막, 몸 전체에 분산된 기관으로 표현한다. 기존의 두 눈 달린 공통 머리 제작 함수를 사용하지 않는다. 환경 표식은 동굴·산성·열수뿐 아니라 온대·숲·습지·해양 사례도 포함한다. 모든 행성에 생명을 강제로 배치하지 않는다.

## 원본과 재생성

원본은 art/blender/bestiary/bio_<family>_01~10.blend, 게임 형상은 우주-비즈니스/assets/models/bestiary/의 near/far GLB다. forms.json의 collection=aberrant로 추가분을 찾는다. eye_count와 sensory_type을 도감에도 표시한다.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_aberrant_bestiary.py
    python3 tools/bestiary/audit_catalogue.py
    ./tools/godot.sh --headless --editor --import
    ./tools/render_bestiary.sh --start=500 --end=600
    python3 tools/bestiary/build_boards.py --aberrant
    ./tools/show_bestiary.sh -- --aberrant
    ./tools/show_bestiary.sh -- --aberrant --attack-captures
    BESTIARY_FILM_FRAMES=/tmp/aberrant-film-frames ./tools/show_bestiary.sh -- --aberrant --film-captures
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/bestiary/encode_film.py -- /tmp/aberrant-film-frames docs/production/media/bestiary/aberrant/attacks.mp4

기존 제작 도구는 추가 컬렉션을 보존하고, 추가 제작 도구는 기존 500개의 원본·GLB를 덮어쓰지 않는다. 렌더 도구는 구조군당 모델 수가 25개로 고정됐다고 가정하지 않는다.

## 검수와 범위

추가 100개와 전체 라이브러리 검수를 마쳤다. 아래는 제작 검수 결과이며 사용자 최종 아트 승인이나 게임 통합 완료를 뜻하지 않는다.

공격은 이름 붙인 부품의 절차 동작과 전조·궤적·파편·분사 효과다. 실제 생존·출현 확률·능력치·공격성·명중·피해·6인 동기화는 메인 통합 범위이며 모든 추가 사례는 spawn_enabled=false로 유지한다.


### 2026-09-06 검증 결과

- 추가 Blender 원본 100개·근거리/원거리 GLB 200개를 생성했다. 기존 500개 모델의 GLB 1,000개는 작업 시작 시 해시와 일치한다. [보존·감각기관 수량](media/bestiary/aberrant/anatomy-verification.json)
- [Blender 원본 검사](media/bestiary/aberrant/source-verification.json)에서 100개 모두 실제 감각기관 수가 메타데이터와 일치하고, 기존 두 눈 머리 생성물을 사용하지 않았음을 확인했다.
- [전체 형상 검사](media/bestiary/geometry-audit.json): 600개 고유 형상, 중복 0개, 외형 12,000개. 추가분 근거리 삼각형은 2,616~57,844개다.
- [전체 동작 검사](media/bestiary/verification.json) 13,022항목·[기본 색 일치 검사](media/bestiary/color-verification.json) 880항목·[도감 조작 검사](media/bestiary/gallery-verification.json) 15항목, 실패 0건. 추가 공격형 70개의 실제 부품 움직임·효과 표시·두 LOD 일치도 포함한다.
- 추가 기본 렌더 100장·그늘/역광 200장·원거리 100장·외형 변형 2,000장. [전체 이미지 검사](media/bestiary/render-verification.json)는 기본 600장·조명 1,200장·원거리 600장·변형 12,000장을 확인했고, 모델별 20개 변형 이미지의 픽셀 중복이 없다.
- 추가 10개 형상 모음판으로 100개를 모두 눈으로 검토했다. 가지 눈의 동공이 표면에 묻히는 문제를 수정·재생성·재촬영했다. 대표 10개 구조군의 주광·그늘·역광·원거리 비교와 공격 7개 구조군의 전조·공격·회복을 검토했다.
- 공통 렌더 도감에 100개를 추가했다. 렌더 라이브러리는 총 600개, 외형 프로필은 12,000개다. 기존 게임 자산의 등록은 보존한다. [공통 INK 계약 검사](media/bestiary/aberrant/ink-contract-verification.json)는 자산 634개·20,012항목, 실패 0건이다. 이번 추가분에서 게임 전체 회귀 검사를 재실행했다는 의미는 아니다.
- 추가분의 파일 내용 기준 용량: 게임 GLB 약 61.1 MB, 도감 미리보기 약 5.4 MB, 편집 원본 약 20.2 MB. 검수 이미지·캐시·백업·영상 임시 프레임을 제외한 값이다. [용량 기록](media/bestiary/aberrant/storage.json)

[추가 10개 구조군](media/bestiary/aberrant-overview.jpg) · [공격 비교 1](media/bestiary/aberrant/attack-board-1.jpg) · [공격 비교 2](media/bestiary/aberrant/attack-board-2.jpg) · [조명 비교 1](media/bestiary/aberrant/lighting-board-1.jpg) · [조명 비교 2](media/bestiary/aberrant/lighting-board-2.jpg) · [도감 화면](media/bestiary/gallery-ui.png)

![추가 100개의 10개 구조군 대표](media/bestiary/aberrant-overview.jpg)

[21초 공격 시연 영상](media/bestiary/aberrant/attacks.mp4) — 7개 공격 구조군을 각 3초, 30fps·630프레임으로 촬영한다. 영상의 실제 프레임 수와 디코딩 검증은 [영상 기록](media/bestiary/aberrant/video-verification.json)을 따른다.
