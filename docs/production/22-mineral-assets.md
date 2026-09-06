# 광물·보석 19종 — 흙 받침 없는 광체

2026-09-06 사용자 요청 반영. 소재 명칭은 **암흑광**, 보석은 **루비·사파이어·에메랄드·다이아몬드**다. 공허 명칭은 미래 콘텐츠용으로 남긴다. 게임 용도·강화 제안은 [광물·보석 설계](../game/14-minerals-gems-and-enhancement.md)가 원본이다.

## 제작과 연결

- 산업 소재 12종: 철, 구리, 알루미늄, 규소, 티타늄, 니켈, 리튬, 황, 인산염, 희토류, 성핵광, 암흑광.
- 보석 원석 4종: 루비, 사파이어, 에메랄드, 다이아몬드.
- 기존 별도 자원 3종: 암석, 얼음, 희귀 결정. 기존 `crystal`을 보석으로 바꾸지 않는다.

[Blender 생성기](../../tools/build_minerals.py)로 편집 가능한 `.blend` 38개와 GLB 38개(19종 × A/B)를 제작했다. [원본·삼각형 기록](../../art/blender/minerals/manifest.json), [시드용 자원 정의](../../우주-비즈니스/data/minerals.json), [공통 도감 목록](../../우주-비즈니스/data/render_assets.json)에 연결한다. 이전 원본 `art/blender/ore_*.blend`는 제작 이력으로 보존하며 새 원본은 `art/blender/minerals/`에 있다. 구 `build_assets.py`는 광석 출력을 덮어쓰지 않고 전용 생성기로 안내한다.

철·구리·암석·얼음·희귀 결정의 기존 `ore_<id>.glb` 경로를 교체했다. 현재 원정의 비동기 자원 로더와 기존 행성 화면이 같은 새 모델을 사용한다. 채집 대상 ID, 충돌, 잔량에 따른 크기 변화, 채집 연출·음원 경로와 저장 재고는 유지한다. 새로운 14종의 실제 광맥 배치와 채집 규칙은 아직 활성화하지 않았다.

## 형태와 배치

모든 내보낸 메시·재질은 해당 자원 자체다. 흙 덩어리, 모암 받침, 원형 바닥, 잔디를 넣지 않는다. 암석 자원 자체의 바위 조각은 유지한다. 지표 높이에 원점을 두고 하단 일부가 지면 안에 들어가도록 제작했다. `placement.embed_m`은 하단 매입 여유의 설명이며 현 배치 코드에서 추가로 빼는 오프셋이 아니다. 깊이 태그는 배치 후보이며 지하 모델에 흙을 포함하라는 뜻이 아니다.

금속의 덩어리·판상·가지, 보석의 육각 기둥·배럴·팔면체, 성핵광의 방사형 결정, 암흑광의 어두운 층리로 실루엣을 구분한다. 재질 색은 게임 내 식별을 위한 표현이며 순수 금속의 실물 외관이나 실제 천체에서 관측한 광상으로 해석하지 않는다. 불투명 보석 면과 작은 하이라이트를 사용해 INK 윤곽과 원석 형태를 유지한다.

## 행성 시드에서 사용할 데이터

`FrontierMinerals.entry(id)`로 모델·한국어 이름·종류·색·지질/깊이 태그를 읽고 `candidates(geology, depth, landable)`로 정렬된 후보 ID를 얻는다. 착륙 불가 천체는 빈 후보를 돌려준다. **후보 필터는 행성의 자원 구성·수량을 생성하는 완성된 생성기가 아니다.** 후속 시드 작업에서 행성별 주력/보조/희귀 자원과 광맥 위치·품위·잔량을 결정하고 생성 버전을 저장해야 한다. 신규 소재를 기존 경제 테이블에 일괄 추가해 모든 행성의 레시피·재고를 우발적으로 바꾸지 않는다.

## 확인한 범위

Blender 5.2.1 LTS Cycles에서 19종의 A/B 38개를 렌더하고, Godot 4.7.2 Metal Forward+ / Apple M2에서 공통 INK 재질·윤곽과 실제 `FrontierBusinessSiteView` 로더/엔티티 생성을 확인했다. 38개 모델 로드·공통 셰이더·받침 제외 검사와 기존 5종의 시드 지표 높이 접지를 확인했다. [검증 결과](media/minerals/godot/verification.json)를 보존한다.

실제 채집을 끝까지 수행하는 조작·사운드·다중 클라이언트 회귀는 이번에 반복하지 않았다. 기존 모델 경로를 교체한 범위의 최소 확인이다. 지하 분포·보석 강화·신규 레시피·고밀도 광맥 성능은 후속 구현/검증 사항이며 렌더 성공을 최종 아트 승인으로 간주하지 않는다.

[Blender 모음판](media/minerals/blender-board.png) · [Godot INK 모음판](media/minerals/godot-board.png) · [기존 5종 지표 접지](media/minerals/godot/surface-contact.png)

재생성 순서:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_minerals.py
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh --script res://tests/render_minerals.gd
python3 tools/mineral_contact_sheets.py  # Pillow가 설치된 Python
```

## A/B 형태와 고정 배치 — 후속 적용

사용자가 같은 자원마다 B형을 하나씩 추가하는 방식을 승인했다. A형은 밀집 군집, B형은 한쪽에 큰 조각이 있고 낮게 이어지는 비대칭 광체다. 색과 결정의 구조 계열은 같으며 두 형상 모두 흙 받침이 없다. [Blender A/B 비교](media/minerals/blender-variants-board.png) · [Godot A/B 비교](media/minerals/godot-variants-board.png).

`minerals.json`의 각 자원에 `variants` 2개를 등록했다. `FrontierMinerals.appearance(resource_id, planet_seed, vein_id)`는 `mineral-visual-v1` 구분자로 A/B, 수평 회전 0~360°, 균일 크기 85~115%를 결정한다. 전역 난수나 로드 순서를 쓰지 않아 같은 버전과 행성 시드·광맥 ID에서는 다시 생성해도 같다. 원정에서는 행성의 `streams.resource`, 기존 행성 화면에서는 저장된 `seed`를 사용한다. 매장량·품질·채집 보상은 외형 크기로 바꾸지 않는다.

기울기는 0°로 유지한다. 지형 법선에 맞춘 기울임은 경사 접지까지 다룰 후속 작업이다. 현재 원정과 기존 행성 화면의 실제 모델 선택 경로에 연결했고, 잔량 축소는 시드 크기에 곱하도록 해 매 갱신마다 크기 변화가 초기화되지 않게 했다. 기존 저장의 자원/광맥 ID와 재고는 바꾸지 않으며 예전 세계도 새 외형 규칙으로 표시된다. 향후 외형 버전이나 변형 목록 변경 시 기존 규칙을 보존하거나 명시적으로 이관해야 한다.

이번 최소 검사는 38개 실제 로더·렌더, A/B 선택, 동일 입력 재생성, 행성 시드 차이, 배치 회전·크기와 축소용 기본 크기 보존, 기존 5종 지표 접지를 확인한다. 다중 클라이언트 재접속 실기 검사는 반복하지 않았다.

B형만 다시 제작할 때는 생성기에 `-- --variant-b`를 넘긴다. 인자 없이 실행하면 A/B 전체와 데이터·도감 등록을 재생성한다.

## 후속 갱신 — 실제 은하 분포 연결

이 문서의 초기 제작 단계 이후 [자원 기반 은하](../production/25-galactic-core-and-resource-world.md)에서 새 세계의 행성별 분포·지역 광맥·신규 광물/보석 채집·운반·저장을 연결했다. 강화 소비처·신규 제작 레시피는 계속 후속이며, 위의 “분포 미연결” 설명은 초기 모델 제작 당시 범위다.
