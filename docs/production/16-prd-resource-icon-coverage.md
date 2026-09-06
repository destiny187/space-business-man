# PRD 재화 SVG 전체 대조표

2026-09-06 현재 PRD에 명시된 재화·재료·표본·지식 범주에 대한 SVG **73종**이다. 기존 6종에 67종을 추가했다. 게임의 최종 아이템 총수가 73개로 확정됐다는 뜻은 아니다. PRD는 모든 합금·원소·연료의 개별 종류를 아직 정하지 않았으므로 명시된 범주마다 공통 아이콘을 제공한다. 물질과 지식을 같은 소비 재화로 취급하지 않는다.

기본 자원표의 `iron_ore`, `copper_ore`, `rare_mineral`은 실행 ID `iron`, `copper`, `crystal`에 별칭 연결했다. 누락됐던 `bio_sample`도 포함한다. 항로 연료·부품·재료의 구체적 화학종이나 별도 유료 화폐는 추가하지 않았다. 아이콘 ID는 UI 자산 식별자이며 경제/저장 카탈로그 항목 추가가 아니다.

생명체 600종은 개별 종의 모델·도감 자산이 있고 시드별 계통이 존재한다. 표본에는 미생물·동물·식생 공통 아이콘과 실제 종 이름을 함께 표시하며, 이 아이콘 묶음을 600종 초상화로 표시하지 않는다. PRD에 명시된 대표 발견 사례는 별도 5종을 제공한다.

## 구현 연결

- 기본 HUD·보관함·비용·채집 알림은 기존 연결을 유지한다.
- 생태 도감과 표본 화물 선택 목록은 실제 생물 분류별 아이콘을 사용한다.
- 현장 공학의 3개 과제 선택 목록에는 각 과제 전용 아이콘을 사용한다.
- 나머지 계획 자산은 공통 레지스트리에 등록하여 `texture(id)`, `view(id)`, `markup(text)`로 즉시 사용할 수 있다. 미구현 연료·정제·배양 생산 기능을 새로 만들지 않는다.
- 전력·산소·배터리·생물량은 거래 재화가 아닌 운영 지표로 별도 분류한다.

## 파일·출처

각 SVG는 `우주-비즈니스/assets/ui/resources/`에 있다. 기계 판독 원본은 `우주-비즈니스/data/resource_icons.json`이다. 아래 상태는 아이콘이 아닌 해당 게임 개념의 상태다. 모든 행의 SVG는 제작 완료했다.

### 기초 자원

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `iron` | 철 | 현재 데이터/자산 유형 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `copper` | 구리 | 현재 데이터/자산 유형 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `stone` | 암석 | 현재 데이터/자산 유형 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `ice` | 얼음 | 현재 데이터/자산 유형 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `crystal` | 희귀 결정 | 현재 데이터/자산 유형 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `credits` | 크레딧 | 현재 데이터/자산 유형 | [catalog.json](../../우주-비즈니스/data/catalog.json) |

### 채집·물질

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `water` | 물 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `volatile` | 휘발성 물질 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |
| `element` | 원소 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `mineral_sample` | 광물 시료 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `meteorite_sample` | 운석 시료 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `frozen_sample` | 동결 표본 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |
| `inert_sample` | 비활성 시료 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |

### 산업 재료

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `iron_parts` | 철 부품 | PRD 설계 범주 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `electronic_parts` | 전자 부품 | PRD 설계 범주 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `refined_metal` | 정제 금속 | PRD 설계 범주 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `alloy` | 합금 | PRD 설계 범주 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `intermediate_material` | 중간재 | PRD 설계 범주 | [02-planets-resources-and-building.md](../../docs/game/02-planets-resources-and-building.md) |
| `catalyst` | 촉매 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `adsorbent` | 흡착제 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `supply_material` | 공급 물질 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `heat_exchange_material` | 열 교환 소재 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `shielding_material` | 차폐 소재 | PRD 설계 범주 | [08-open-world-and-underground.md](../../docs/game/08-open-world-and-underground.md) |
| `reflective_material` | 반사 소재 | PRD 설계 범주 | [08-open-world-and-underground.md](../../docs/game/08-open-world-and-underground.md) |
| `heat_resistant_material` | 내열 소재 | PRD 설계 범주 | [08-open-world-and-underground.md](../../docs/game/08-open-world-and-underground.md) |
| `circuit` | 회로 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `salvage_parts` | 인양 부품 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |
| `repair_parts` | 수리 부품 | PRD 설계 범주 | [03-robots-and-automation.md](../../docs/game/03-robots-and-automation.md) |
| `research_parts` | 연구 부품 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |

### 생태·표본

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `bio_sample` | 생체 표본 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `microbe_sample` | 미생물 표본 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `animal_sample` | 동물 표본 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `plant_sample` | 식생 표본 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `dormant_culture` | 휴면 배양체 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `spores` | 포자 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `egg` | 알 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `seed` | 씨앗 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `tissue_sample` | 조직 시료 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `substrate` | 기질 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `feed` | 먹이 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `oxidizer` | 산화제 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `enzyme` | 효소 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `standard_culture` | 표준 균주 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `support_pack` | 지원 팩 | 현재 데이터/자산 유형 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |

### 발견 사례

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `lithotherm_sample` | 리소섬 표본 | PRD 가상 사례 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `silver_crystal` | 은빛 결정 군락 | PRD 가상 사례 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `fog_leaf` | 응결 잎 | PRD 가상 사례 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `carbonate_shell` | 탄산염 껍질 | PRD 가상 사례 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `acid_microbe` | 황산 적응 미생물 | PRD 가상 사례 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |

### 지식 자산

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `scan_data` | 스캔 데이터 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `metabolic_record` | 대사 기록 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `structural_measurement` | 구조 측정 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `operation_log` | 작동 로그 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `landscape_observation` | 경관 관측 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `cultural_knowledge` | 환경·문화 지식 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `space_observation` | 우주 현상 관측 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `research_principle` | 발견 원리 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `validation_record` | 검증 기록 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `blueprint` | 설계도 | 영구 지식 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |

### 항해·유적

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `ancient_artifact` | 유물 | PRD 설계 범주 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `relic_fragment` | 유물 조각 | PRD 설계 범주 | [08-open-world-and-underground.md](../../docs/game/08-open-world-and-underground.md) |
| `fuel` | 항로 연료 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |
| `supplies` | 보급품 | PRD 설계 범주 | [05-economy-and-progression.md](../../docs/game/05-economy-and-progression.md) |
| `landing_kit` | 착륙 키트 | PRD 설계 범주 | [05-economy-and-progression.md](../../docs/game/05-economy-and-progression.md) |
| `ship_module` | 우주선 모듈 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |
| `prototype` | 시제품 | PRD 설계 범주 | [07-space-exploration-and-ships.md](../../docs/game/07-space-exploration-and-ships.md) |

### 현장 공학

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `mineral_scaffold` | 광물 공생 배양체 | 현재 공학 연구 기록 | [field_engineering.json](../../우주-비즈니스/data/field_engineering.json) |
| `thermal_exchange` | 저온 적응 열교환막 | 현재 공학 연구 기록 | [field_engineering.json](../../우주-비즈니스/data/field_engineering.json) |
| `water_membrane` | 건조 적응 순환막 | 현재 공학 연구 기록 | [field_engineering.json](../../우주-비즈니스/data/field_engineering.json) |

### 운영 자원·지표

| SVG ID | 이름 | 개념 상태 | 근거 |
| --- | --- | --- | --- |
| `power` | 전력 | 운영 자원·상태 지표 | [04-terraforming-and-sales.md](../../docs/game/04-terraforming-and-sales.md) |
| `oxygen` | 산소 | 운영 자원·상태 지표 | [09-discovery-research-and-ecology.md](../../docs/game/09-discovery-research-and-ecology.md) |
| `battery` | 배터리 | 운영 자원·상태 지표 | [03-robots-and-automation.md](../../docs/game/03-robots-and-automation.md) |
| `biomass` | 생물량 | 운영 자원·상태 지표 | [ecology.json](../../우주-비즈니스/data/ecology.json) |

## 검증

`test_prd_resource_icons.gd`는 모든 SVG의 엔진 로딩·128×128 크기·중복 ID·출처 파일·PRD 별칭과 실행 자원/공학 과제 누락을 검사한다. 전체 모음은 독립 SubViewport로 렌더하여 화면 높이 제한으로 하단이 잘리지 않게 한다.

[전체 73종 모음](media/resource-icons/prd-board.png)

실제 검증 결과: `PRD_ICON_CHECKS 238 FAILURES 0 ASSETS 73`, 기존 재화 HUD 검사 `RESOURCE_ICONS failures=0`, 협동 작은 화면 `CREW_LAYOUT_CHECKS 12 FAILURES 0`, 생태 화면 `ECOLOGY_UI_CHECKS 30 FAILURES 0`. SVG 73개의 내용 해시가 모두 달라 동일 파일 복제도 없다. 전체 모음 1600×2130은 실제 Godot 렌더에서 검토했다.

## 실제 플레이 화면 연결 보완 — 2026-09-06

사용자의 ‘실제 게임에 적용’ 확인 요청에 따라 텍스트로 남아 있던 현재 구현 화면을 추가 연결했다. 사업 건설 선택의 재료를 아이콘 비용 행으로 표시하고, 보급 목록·생물공학 버튼·공동 자금·생태 연구실 재고·협동 표본 목록·기존 상점 버튼·로봇 자원 지정에 적용했다. 새 우주선 정비 UI에는 모듈 아이콘, 제작·추첨 재료와 크레딧, 개량 부품을 연결했다. 이번 변경은 UI 표시이며 제작·추첨·경제·네트워크의 규칙은 수정하지 않았다. 부품은 새 정비 시스템의 연구 부품이며, 실물 재고가 없는 계획 품목을 새로 지급하지 않는다.

`test_resource_panels.gd`의 9개 확인 항목(선택 비용·보급/모듈 아이콘·통화/부품 표시·원래 버튼 명령·작은 화면 경계)과 `test_crew_layout.gd`의 12개가 통과했다. 기존 HUD 검사도 통과했다. [실제 정비 패널 렌더](media/resource-icons/shipyard-ui.png)는 독립 UI 검사용 자금/부품 예시값으로 촬영했다.

프로젝트의 Godot 장면과 UI 코드에 직접 반영한 상태다. 과거에 내보낸 1.2 앱/ZIP은 별도 스냅샷이며 이 문서의 소스 적용 상태와 구분한다.

커밋 분리: 우주선 정비 화면은 별도 메인 작업의 신규 파일이므로 그 파일과 관련 게임 로직은 아이콘 커밋에 포함하지 않는다. 작업 트리의 아이콘 연동은 보존하며, 패널 검사는 정비 파일이 존재할 때 해당 항목을 추가 검증한다. 기존 사업·협동·생태 UI와 공통 아이콘 자산은 독립적으로 커밋한다.
