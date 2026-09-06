# 게임 설계 문서 목차

2026-09-06 최신 시작 구조: [무작위 은하·지구 출발·별도 대기실](production/20-galaxy-start-and-lobby.md). 새 생성기/세션 흐름과 기존 1.2 및 이전 확장 검증을 구분한다.

루트 진입점: [AGENTS.md](../AGENTS.md). 이 문서 묶음은 최초 아이디어와 변경된 목표를 시스템별로 관리한다. **2026-09-06 현재 목표는 단일 은하의 탐사·티어/시드 행성·지표/지하·발견 연구·표본 이식·외계문명·호스트 포함 6인 공동 승선으로 확장했다.** 먼저 [고도화 계획](planning/06-exploration-expansion-roadmap.md)과 [은하·티어·시드](game/11-galaxy-tiers-and-seeds.md)를 읽는다. 현재 1.2의 구매 기반 실행은 [구현 현황](planning/03-implementation-status.md), 사용법은 [실행 안내](release/01-playing-and-building.md)를 따른다. 새 문서가 새 기능 구현을 의미하지 않는다.

## 상태 표기

| 표기 | 의미 |
| --- | --- |
| 확정 요구사항 | 사용자가 직접 제시한 게임 방향과 기능 |
| 원안 예시 | 사용자가 설명에 사용한 사례·수치. 콘텐츠 및 밸런스 확정과는 구분 |
| 설계 제안 | 일관된 구현을 위해 추가한 초안. 사용자 승인 전까지 변경 가능 |
| 미정 | 선택에 따라 구현 비용·경험이 크게 달라지는 항목 |

아래 문서에서 ‘설계 제안’ 절의 규칙·수치·데이터 구조는 모두 제안이다. 구체적이라는 이유만으로 확정 요구사항이 되지 않는다. 코드 구현 상태와 기획 상태도 별개다.

## 읽는 순서와 소관

| 문서 | 담당하는 내용 |
| --- | --- |
| [게임 비전과 핵심 루프](game/01-vision-and-loop.md) | 세계관, 플레이어 역할, 재미의 중심, 한 회차의 흐름 |
| [행성·자원·건축](game/02-planets-resources-and-building.md) | 행성 특성, 수동 채집, 자원, 시설 배치, 초반 경험·화면 |
| [광물·보석·강화](game/14-minerals-gems-and-enhancement.md) | 행성별 광물·최고급 공통 소재·지하 보석·캐릭터/장비 강화 목표·미정 |
| [로봇·자동화](game/03-robots-and-automation.md) | 제작, 랜덤 등급·특성, 작업·운반·전력·고장 |
| [테라포밍·행성 판매](game/04-terraforming-and-sales.md) | 환경 상태, 설비 효과, 평가 등급, 매각 절차·가격 |
| [경제·기술·계승](game/05-economy-and-progression.md) | 탐사 투자·계약·매각, 기술 상점, 자산 회수·수송 |
| [탐험·이벤트·문명](game/06-exploration-and-civilizations.md) | 발견 종류, 보상, 선택과 장기 결과 |
| [우주 탐험·우주선](game/07-space-exploration-and-ships.md) | 항해·후보 선정·개발 권한·선체/모듈 성장·해적·사건 |
| [오픈월드·지하](game/08-open-world-and-underground.md) | 지역·수직 탐험·굴착·발견 밀도·위험·재방문 |
| [발견·연구·생태](game/09-discovery-research-and-ecology.md) | 원리 연구·고유 생물 출현·표본·이식·생물 모방·열 사례 |
| [외계문명·외교](game/10-alien-civilizations-and-diplomacy.md) | 문명 단계·접촉·환경 목표·협약·교역·갈등 |
| [은하·티어·시드](game/11-galaxy-tiers-and-seeds.md) | 단일 은하·중심 방향 진행·티어 분포·시드 계층·생물 사례 선택 |
| [호스트 협동·승무원](game/12-host-coop-and-crew.md) | 호스트 포함 6인·개인 장비·같은 우주선·역할·합류/이탈·시간 |
| [아트·Blender 제작](production/01-art-and-blender.md) | 카툰 표현, 에셋 목록, 제작·복구·내보내기 과정 |
| [1.2 렌더링 품질과 성능](production/03-rendering-and-performance.md) | 조명·그림자·접지 음영·재질·Blender 암벽·프리셋·실측 비교 |
| [데모 이후 렌더링 품질 연구](production/04-visual-target.md) | 신규 모델·배경을 포함한 독립 고품질 장면, 실행·조작·검토 범위 |
| [공식 렌더링 품질 기준 — INK v1](production/06-rendering-quality-standard.md) | **모든 후속 자산에 필수**: 승인 스타일·공통 셰이더·31종 렌더 목록·완료 조건 |
| [굵은 검은선 카툰 기준작](production/05-ink-style-study.md) | 승인한 로봇·자원·풀·건물 네 가지 실제 렌더와 제작 이력 |
| [첫 생물 리소섬 시연](production/07-lithotherm-specimen.md) | 독립 생물 원본·LOD·상태 표현·관찰실 |
| [생물 기본 모델 600개 렌더링](production/08-bestiary-rendering.md) | 기존 500개와 추가 이형 100개·공격 모션/효과와 검증 |
| [이형 생물 추가 100개](production/09-aberrant-bestiary.md) | 무안·단안·복안·다안, 새 해부 구조 10군의 제작 기록 |
| [사운드·ElevenLabs 제작](production/02-audio-and-elevenlabs.md) | 사운드 방향, 우선 목록, 프롬프트, 생성·검수 과정 |
| [Godot 기술 설계](technical/01-godot-architecture.md) | 현재 저장소, 제안 구조, 시뮬레이션 경계, 성능·검증 |
| [데이터·세이브 설계](technical/02-data-and-save.md) | 정의와 인스턴스, 식별자, 저장 범위, 중복 방지 |
| [실제 천체 데이터·월드](technical/03-universe-data-and-world-streaming.md) | NASA/JPL 자료·출처·생성층·청크·지하·활성/집계 시뮬레이션 |
| [협동 네트워크·세션 저장](technical/04-coop-networking-and-session-save.md) | 호스트 상태 확정·명령 검증·공동 선체·관심 지역·개인/세계 저장 |
| [MVP와 개발 단계](planning/01-mvp-and-roadmap.md) | 첫 완결 루프, 단계별 산출물·완료 조건, 확장 순서 |
| [결정 대기 항목과 위험](planning/02-decisions-and-risks.md) | 확정사항 추적, 큰 미정 항목, 위험, 결정 이력 |
| [실제 구현 현황과 검증](planning/03-implementation-status.md) | 코드·에셋·검증 근거·실행 범위 |
| [원안 요구사항 인수 표](planning/04-requirement-audit.md) | R-01~R-19별 실제 제공 결과 |
| [1.1 인터페이스·연출·입문 경험](planning/05-interface-and-feedback.md) | 사용자 피드백 반영, 실제 동작 효과, 단계별 시작 |
| [탐험 중심 고도화 계획](planning/06-exploration-expansion-roadmap.md) | 요청 대응·추가 재미·첫 실증·E0~E5·협동 기반 실증·X-01~X-16 미완료 인수 |
| [탐험 확장 개발 기록](planning/07-expansion-development-log.md) | E0부터의 실제 구현·검증·부분 완료·후속 순서 |
| [최종 설계 개발 대조표](planning/08-expansion-execution-matrix.md) | X-01~X-16·제작/운영 조건·의존성·미완료 연결 |
| [지하 운반 로봇과 실제 물류](production/09-courier-and-surface-logistics.md) | 실제 지형 경로·물리 운반·재로드·Blender 바퀴·성능 |
| [행성 시드와 생명체 통합](production/11-seeded-ecology-integration.md) | 실제 접지·스캔/분석·표본 항해/이식·휴면·저장·미연결 매질 |
| [생물 관측과 현장 공학](production/14-biological-field-engineering.md) | 원산지 증거·시제품·가동 설비 시험·개조·실제 지역 처리량 |
| [탐험 산업과 복원 계약](production/13-expedition-industry-and-contracts.md) | 무료 개발 등록·광맥/창고·공동 건설·로봇·지역 환경·계약 정산·재투자 |
| [공동 지표와 생태 동기화](production/12-shared-surface-and-ecology.md) | 공동 착륙·굴착·스캔/연구·표본 운송·재접속·호스트 저장 |
| [공동 원정선과 6인 플레이](production/10-crew-cabin-and-playtest.md) | 실제 ENet·개인 장비·3D 선내/선체·재접속/화물·검증 범위 |
| [실행·운영 안내](release/01-playing-and-building.md) | 실행·조작·저장·문제 해결·빌드·라이선스 |

## 문서 유지 규칙

- 시스템 규칙은 소관 문서가 기준이다. 다른 문서는 내용을 재정의하지 않고 연결한다.
- 원안 예시에는 철 100·구리 10의 로봇 제작, 충격 피해 20% 감소 특성, 산소 생성력 55의 미생물이 있다. 모두 의미를 보존하되 실제 수치 확정은 플레이 검증 후 한다.
- 기존 1.2 실행은 로컬 싱글플레이·1인칭 원격 조종·유한 구역이다. 새 탐험 실행과 공동 원정의 실제 범위는 구현 현황과 제작 검증 기록을 따른다. 단일 은하·티어/시드·자유 탐사·지하 경험은 새 확정 방향이며 호스트 포함 최대 6인 협동도 확정 방향이다. 구형 월드·전면 복셀·최종 조작 주체·온라인 연결 서비스는 미정이다.
- 제작·기술 문서의 폴더와 에셋 목록은 목표 설계이며, 생성된 산출물 목록이 아니다.
- 게임 규칙 변경 시 관련 화면, 데이터·저장, 완료 조건도 함께 점검한다.

- [원정선 모듈 성장과 이동 실험실](production/16-vessel-refits-and-progression.md): E3 첫 범위, 실제 장착·제작·추첨·개량·수송 용량·검증과 후속 제한.

- [혼자 시작·착륙 UI 수정](production/17-solo-entry-and-surface-ui.md): 현재 시작 경로, 오프라인 원정, 착륙 시 패널 숨김과 직접 조작 검증.

- [개인 설정·그래픽·시야거리 및 원경 누락 수정](production/18-client-settings-and-view-distance.md)

- [원정 기본 플레이 품질 복구](production/19-play-quality-restoration.md): 첫 커밋 대비 장비·시청각 피드백·건설 카드 연결과 검증.

- [에셋 버전 관리](technical/05-asset-version-control.md): Git LFS, 생성 캡처 제외, 새 환경 설치와 이력 보존.

- [태양계 8행성 Blender 제작](production/21-solar-system-blender.md): 원본 8개·근거리/원거리 GLB 16개·공통 INK·실제 항해 렌더.

## 지상 장비 구조 갱신

[아이템·제작·장착 규칙](game/13-inventory-and-equipment.md) · [구현·Blender/INK 렌더·검증](production/21-ground-equipment.md). 현재 원정의 만능 도구 경로를 대체한다.

- [광물·보석 19종 Blender 제작·시드용 정의](production/22-mineral-assets.md): 기존 광석 모델 교체, 신규 분포·강화는 후속.

- [공통 UI/UX 가이드 FIELD v1](production/22-uiux-guide.md): 시각 표현 우선, 공통 테마·HUD·선택·장착·피드백 기준.
- [지상 HUD·아이템 UI/UX 적용](production/23-uiux-implementation.md): 실제 3D 미리보기·격자·클릭/드래그 슬롯과 확인 범위.

- [지상 체력·스태미나·획득량·레이더](production/24-field-vitals-and-radar.md): FIELD v1 기본 플레이 정보 보완.

- [자원 기반 은하·중앙 블랙홀](production/25-galactic-core-and-resource-world.md): 새 세계의 지역 광맥 생성·채집·저장, 중심 블랙홀 확대 렌더. [기술 구조](technical/06-mineral-galaxy-open-world.md).

- [공통 조사·살아 있는 정착물](production/25-universal-survey-and-living-settlement.md): 광물/생물 스캔과 연구 활용, 테라포밍 이후 정원·서식지 확장 설계.
