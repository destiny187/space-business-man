# 게임 설계 문서 목차

2026-09-08 [부재중 생산·FINCH 소형선 개별 구현](production/57-distributed-industry-and-finch.md): 호스트 세션 중 거점 생산과 같은 항성계의 개인 출동·직접 운송·귀환을 연결했다. 실제 두 클라이언트의 서로 다른 행성 이동, 제작/비행 화면, 화물/재접속을 확인했다. 아래 부재중 생산 일시 정지·전원 동일 행성 전제는 이전 이력이며, 6인 인터넷·구조 회수는 후속이다.

2026-09-08 [지표 텍스처·행성 3계열](production/56-planet-surface-materials.md): 공유 재질 10종·지상 12계열의 복합 표면, 퇴적 분지/결정질 고원/알칼리 광화대의 Blender 원본·궤도 LOD·지상 자연물을 적용했다. 전체 외형은 18계열이며 새 계열은 새 은하에서 생성된다. 확인한 렌더와 후속 경계는 소관 기록을 따른다.

2026-09-08 [생산 거점·직접 운송·첫 P3 생산 구현](production/55-planet-supply-and-tier3.md): 여러 거점의 권리·재고를 유지하고 금속/저온 부품을 운송하여 제작소 Mk.3를 개조한다. 부재중 생산과 추가 표면 계열은 후속 범위다.

2026-09-08 [행성·생물 선별 개선 완료](production/54-planets-and-life-art.md): 600개 기본형 검토·200개 개선/400개 유지, 행성 23종과 9개 지표, 내부/원거리 선 조정 및 실제 렌더 확인.

2026-09-08 승인 전 조사 기록 — [행성 특화·후반 공급망과 재방문](game/17-planet-specialization-and-supply.md): 15계열의 충분성을 외형 수와 경제 역할로 나누고, 신규/강화 후보·주력 자원·수입 수요·복원 계약과 공급 거점 분리·비활성 생산·운송·막힘 방지를 **구현 전 제안**으로 정리했다.

2026-09-08 [행성 종류·지질·렌더링 적용 범위 감사](production/53-planet-coverage-audit.md): 가상 외형 15계열·태양계 8종·지상 9계열·지질 10종을 대조하고 실제 렌더와 환경 표현 공백을 구분했다. [복합 표면 설계](technical/09-planet-surface-materials-and-biomes.md)의 전체 계열 대응표·공통 표현 계약을 보완했다.

2026-09-08 [행성 지표 재질·복합 지역 구조](technical/09-planet-surface-materials-and-biomes.md): 바닥 품질 개선, 지질·기후별 재질 분포, 눈/얼음/습윤 피복, 지역 테라포밍·저장 연결의 **구현 전 설계 제안**. 현재 지표 구현과 구분한다.

2026-09-08 **C00~C17 첫 구현·개별 커밋 완료**. [기본 조작·로봇·시설·환경 HUD](production/46-ground-play-repairs.md), [탐험·연구·협동 사업량](production/47-ground-exploration-growth.md)에 실제 실행·화면·저장 확인과 미확인 범위를 정리했다. [로버·한 대 운송](production/48-rover-and-transport.md)도 현재 게임에 연결했다. [C16/C17 시드 천체 시간·낮밤](production/50-seeded-cycles.md)까지 신규 세계에 연결했다. 구형 모델 재제작·전체 UI 개편·집중 성능 안정화는 별도 후속이다.

2026-09-07 **지상 개선 변경 문서 정리 완료**. 아래 명세에 최종 승인된 [협동 인원별 사업량](game/12-host-coop-and-crew.md)까지 반영했다. 완료 표기는 문서 정리이며 게임 구현·플레이 검증은 별도다.

- [지상 플레이 피드백·개선안·확정 결정](planning/09-ground-play-feedback.md): 문제 7건·개선 5건과 최신 정정. **건설은 가방 실물만 소비**하며 창고 자동 보충은 폐기했다.
- [지상 개선 개발 명세·시간 예산](planning/10-ground-development-spec.md): 코드/데이터 근거, 첫 행성 10~20분·티어별 연구/숙련 계산, 분포·구현 파일·저장·최소 완료 조건. 게임 실행 없이 정적 계산했다.
- [지상 개선 커밋 계획](planning/11-ground-commit-plan.md): C00 문서 기준점·C01~C17 구현 분할, 의존성과 사용자 선택 종료 지점. 첫 구현 범위의 실행·완료 기록을 포함한다.
- [2인 로버·강화 운송](game/16-rover-and-transport.md): 제작·조작·화물·충전/복구·협동·선박 한 대 운송의 소관 설계. 구현과 실제 확인은 C13~C15 제작 기록을 따른다.
- [시드 천체 시간](technical/08-seeded-planetary-cycles.md): 항성계·행성 자전/공전·낮밤·태양/별, 현실 근거·동주기 예외·게임 시간 압축과 기존 저장 경계. 일반/동주기 첫 구현과 검수는 C16~C17 제작 기록을 따른다.

2026-09-07 [우주 탐험 경험·영어 천체명·진입 사운드](production/34-space-experience.md): 5단계 적용과 사운드 제작·검증 기록.

- [2티어 공통 제품·분야별 첫 개조](production/36-tier2-production-and-retrofits.md): 실제 생산·인수·장비/탐험복/로봇/설비/선박 강화와 신규 T2 복원 조건.

- [테라포밍 생산 단계와 고급 제품](game/15-terraforming-production-progression.md): 초반 직접 제작 유지, 후반 정제·화학·합금·배양·코어 생산과 환경 처리 능력의 구현 전 설계.

- [200m 지하·시드 동굴·매장 자원 구조](technical/07-seeded-underground.md): 2026-09-07 확정 방향과 구현 전 설계. 기반암 차단·동굴 연결·지질 경관·미래 아이템/재화 확장 지점을 다룬다.

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
| [Blender 공통 제작 규격](production/49-common-blender-art.md) | 산업 재질 단일 데이터·형태/곡면·출력 규칙·로버/창고 통일·남은 구형 모델 |
| [채광 로봇·환경 시설 재제작](production/51-industry-remodel.md) | 우선 5종 형태 교체·가동부 보존·Blender/INK 렌더·현재 게임 연결 확인 |
| [구형 그래픽 후속 16종](production/52-legacy-art-completion.md) | 시설·장비·발견물·자연물 전량 교체·legacy 0종·INK 렌더·현재/기존 게임 연결 |
| [생산 거점·첫 P3 생산](production/55-planet-supply-and-tier3.md) | 독립 이용권·보유 정산·직접 운송·Mk.3 제작소·실행 확인 |
| [행성·생물 선별 개선](production/54-planets-and-life-art.md) | 600개 기본형 검토·200개 개선/400개 유지·행성 23종·내부/원거리 선 조정 |
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

최신 항해 구조: [항성계 오픈월드·무료 성간 초고속 항해](production/26-stellar-cruise.md).

- [행성 외형·복합 지질·초기 환경·지역 냉각](production/31-planet-diversity.md).

- [항성계 구성과 진입 풍경](production/32-system-diversity.md): 가변 행성 수·궤도 간격·소행성대·위성·고리와 저장 호환.

- [항성 외형 계열과 궤도선 제거](production/33-stellar-appearance.md): 표면·코로나·홍염의 네 계열과 실제 공전 유지.

- [행성 진입·하강·착륙 연출](production/35-planet-arrival.md): 호스트 승인 후 접근·로딩 전환·지표 하강·조작 인계와 ElevenLabs 전용 음원.

- [탐험복 관절 리그·협동 점프](production/37-crew-locomotion.md): 13개 뼈, 현재 원정의 Space 점프·접지·예측/보간·ElevenLabs 이동음과 검수 범위.

- [첫 착륙 광맥·원경·통합 아이템 수정](production/38-first-game-fixes.md): 등록 전 광맥, 기초 자원 보장, 배경 원경 생성, 0개 제외·중첩 격자와 실제 확인 범위.

- [항해 간소화·Esc 메뉴·입력 전환](production/38-navigation-context-and-menus.md): 우측 상단 지도·큰 지도·근접 착륙과 창 전환 시 마우스/시점 복구.

- [시설별 작업 인터페이스](production/39-facility-interactions.md): B 건설과 F 로봇 제작소·시설·창고·착륙선 작업 분리.
- [탐험 배경음악](production/39-music-and-ship-ai.md): ElevenLabs 우주·행성 2분 음악, 장소 전환·반복·음량·메뉴 정지. 여성 음성 제외.

- [착륙 연기·즉시 채광·독립 연구 화면](production/40-smoke-and-research.md)

- [흡입 채집·표면 스캔·카빈 동작 개선](production/40-field-tool-feedback.md): 타격 반동 제거, 연속 흡입 기류·팬 음향, 표면 조사와 실제 창 확인.

- [행성 지상 하늘·지역 테라포밍 대기](production/41-surface-atmosphere.md)

- [초기 8칸 아이템창](production/41-eight-slot-inventory.md): 4×2 수납, 기존 초과 아이템 보존, 후속 개인별 확장 연결점과 실제 창 확인.

- [정거장 교역·선체 획득과 교체](production/42-space-stations-and-hulls.md): 일부 항성계 출현·첫 목적지 제외·물자 거래·SWIFT/MULE·기존 자산 보존과 검증.

- [유한 창고·운송 화물·FPS 시점](production/43-warehouse-and-fps-input.md): 행성/우주선 10칸, 드래그 입출고, 개인 배낭 운송과 실제 창 확인.

- [3D 은하 항로·항속거리·주변 별 항해](production/43-galaxy-routes.md): 거리 제한, 지도 LOD/근처 보기, 미방문 이동, 방향별 별 직접 출발.

- [항성 좌표 영속 캐시·목적지 행성 준비](production/44-navigation-cache.md): 주변 구역 우선 캐시 재사용과 항해 중 행성 모델 사전 준비.

- [자연 진행·2단계·복원 정산 플레이 테스트](production/44-natural-progression-playtest.md): 실제 시작·착륙·연구, 재료 기반 강화/정산 규칙 검사와 계약·창고 UI 진입 차단.

- [자연 진행 차단 복구·초반 철과 얼음](production/45-progression-repairs.md): 계약·보급·로봇 관리 진입 복구, 부적합 배정 거절, T1·T2 시작 광맥과 기존 저장 확인.

- [지상 기본 플레이 개선 C00~C08](production/46-ground-play-repairs.md): 연속 채광·가방 건설·창고·로봇·시설 모션/ElevenLabs·환경 HUD의 실제 구현과 최소 확인.
