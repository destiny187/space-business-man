# SP02 — 실물 표식·운영사·제조사·기업 기록

2026-09-10 사용자 승인에 따라 [SP02](../planning/16-space-corporations-commits.md)를 구현했다. 쿠퍼테크의 현재 심볼은 [전투로봇 투구·어깨 장갑 v3](107-coopertech-sentinel-symbol.md), 표기는 **CooperTech**다.

## 현재 플레이

Lotus 보급 상자, mine 채광로봇, CooperTech 폐기 전투로봇을 바라보고 **E를 유지**하면 실제 장비의 회사 표식과 짧은 소개가 나타난다. 최초 식별 뒤 **J → 발견 도감 → 기업**에 회사 심볼·실제 모델·역할·첫 발견 행성을 남긴다. 영어/한국어 검색과 현재 행성 필터를 이용할 수 있다. 탐사 연구·광물/생물·기존 사건 도감은 유지한다.

회사의 소유권을 제조사로 추측하지 않는다.

| 실물 | 운영 | 제조 | 붙인 표식 |
| --- | --- | --- | --- |
| HERON 보급선 | Lotus | 미확인 | 선체 양측과 상부의 Lotus 도장. 보급 단말에 같은 운영/제조 구분 |
| 투하 보급 상자 | Lotus | 미확인 | 전면 기존 라벨을 새 Lotus 문양으로 교체 |
| 자동 채광로봇 | 원정대 | mine | 전면 정비 명판·후면 제조 표식 |
| 폐기 전투로봇 | 미확인 | CooperTech | 가슴 측면의 장갑 로봇 문양. 약점 코어와 가동 부품은 유지 |

HERON 자체를 공중에서 조사하는 기능은 이번에 추가하지 않았다. Lotus 첫 식별은 착지한 상자로 진행하며, 보급 메뉴에서 선박의 운영 정보를 확인한다. Space Y의 벡터·표시 정의는 준비하지만 아직 만나지 않은 회사를 J에 미리 공개하지 않는다. 화성·새 시설·NPC 함선은 SP03 이후다.

![현장 제조사 식별](media/corporate-presence/coopertech-scan.png)

![960px 기업 도감](media/corporate-presence/corporations-journal-960.png)

## 아트와 제작 경로

`tools/corporate_marks.py`가 기존 네 Blender 원본에 공통 INK 재질의 도장/명판을 붙인다. `art/branding/corporations/*`의 **동일한 소형 SVG**를 면으로 변환하므로 UI와 모델 문양이 따로 바뀌지 않는다. 전체 모델 형상을 다시 설계한 작업은 아니다. 원본 저장 뒤 정적 재질별로 병합해 기존 게임 GLB 경로에 출력한다. 기존 로봇 약점·포신, 드릴/바퀴, 상자 뚜껑, HERON 로터/화물 집게의 부모와 변환을 보존했다. 목록은 `art/blender/corporate-marks.json`에 있다.

Lotus·산업 로봇·사건 생성기에도 같은 제작 함수를 연결해 재생성 시 표식이 사라지지 않게 했다. `tools/export_corporate_ui.py`가 네 회사 소형 벡터를 게임 리소스로 출력한다. 채광로봇·전투로봇의 기존 UI PNG도 새 GLB에서 투명 배경으로 다시 렌더했다.

- [CooperTech INK](media/corporate-presence/robot-godot.png) · [Blender](media/corporate-presence/robot-blender.png)
- [mine INK](media/corporate-presence/miner-godot.png) · [Blender](media/corporate-presence/miner-blender.png)
- [Lotus 상자 INK](media/corporate-presence/supply_crate-godot.png) · [Blender](media/corporate-presence/supply_crate-blender.png)
- [HERON INK](media/corporate-presence/heron-godot.png) · [Blender](media/corporate-presence/heron-blender.png)

## 데이터·저장·협동 경계

`data/corporations.json`은 회사 소개, 실물별 운영/제조 관계와 표시용 모델을 정의한다. `FrontierCorporations`가 호스트의 현재 행성에 실재하는 착지 상자·출고 로봇·구현된 로봇 사건을 선택한다. 기존 스캐너 거리·조준과 지형 가림 판정을 따른다. 클라이언트가 회사명이나 발견 보상을 제출하는 명령은 없다.

기존 E 스캔의 진행·효과·완료음(`ui_discovery`, 기존 ElevenLabs 자산)을 재사용한다. 별도의 성공 소리를 겹쳐 재생하지 않는다. 호스트가 스캔 완료를 저장한 후에만 기업 기록이 공개된다. 회사별 **첫 식별 한 건**으로 한도를 네 개로 제한하며 같은 회사의 전 개체를 무한 기록하지 않는다. 다른 장비를 조사하면 현장 결과는 그 장비의 정보를 보여 주고 첫 발견 이력은 유지한다.

기록은 선택적 `crew.corporations`에 둔다. 필드가 없는 기존 저장은 미발견 상태로 읽으며 기존 사건 ID·위치·전리품·보상·소유권을 다시 쓰지 않는다. 구 사건 ID `illuti_dormant_combat_robot`와 아이콘 경로는 호환용으로 유지한다. 소형선의 별도 행성 컨텍스트도 새 기록을 공동 세계로 반영한다. 기업 정의를 협동 콘텐츠 해시에 포함하고 기존 신뢰 채널의 도감 페이지에 기업 분류를 허용한다.

## 실제 확인과 남은 범위

Blender 5.2.1 LTS와 Godot 4.7.2 / Metal Forward+에서 네 원본/GLB·단독 INK 렌더를 확인했다. 기존 Anim_/Socket_/ToolRotor 변환은 원본 편집 전후 동일했다. HERON은 상부 큰 도장을 추가해 내려다볼 때도 운영사 표식을 읽게 했다.

준비된 격리 세계에서 현재 원정의 세 실물을 E로 조사하고, 표시·J 검색·미발견 Space Y 비공개·운영/제조 구분·저장 재로드·소형선 컨텍스트 반영을 확인했다. [핵심 실행 기록](media/corporate-presence/play-check.txt)은 28개 확인, 실패 0이다. 준비된 물자·로봇·사건 배치를 사용했으며 자연 성장 전체를 검증한 것은 아니다.

실제 화면에서 발견한 조사 카드와 환경 HUD 겹침을 수정하고, 기업 미리보기에서 명판이 카메라를 향하도록 바꿨다. [후속 화면 확인](media/corporate-presence/layout-check.txt)은 4개 확인, 실패 0이다. 960×640에서 핵심 관계를 먼저 보이고 긴 소개는 스크롤한다. 기존 조사 완료 효과·사운드 경로와 전투로봇의 기동/냉각 표현은 현재 장면에 연결되어 있다.

이번에는 새 음원을 만들지 않았고 음색 청취·전체 채광/운반 주기·보급 비행 전 주기·실접속 다중 클라이언트·Windows·전수 장비 리브랜딩·장시간 성능 검사는 하지 않았다. 기존 선박/로봇의 원본·동작 연결점을 보존한 실제 표식/조사 구현 범위이며, 새 우주 운송·화성·기업 세력 시뮬레이션 완료로 확대하지 않는다.
