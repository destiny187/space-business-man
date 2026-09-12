# 게임 설계 문서 목차

2026-09-12 [해적 폭발·카툰풍 조우음](production/143-pirate-blast-and-warning.md): 구형 불꽃/고정 링을 섬광·분출·잔광·부품 파편으로 교체하고 전용 ElevenLabs 전자 경고음을 연결했다. 진입음 중첩·메뉴 재진입 반복을 고쳤으며 실제 격파 영상과 13개 확인, 최종 청감 미확인 범위를 기록한다.

2026-09-12 [비행 전투 동작·표현 고도화](production/141-pirate-combat-quality.md): 실제 돌입/측면 통과·롤 이탈과 교란 장치 전개, 이동 탄/회피·관절 반동·부착형 실드·지연 폭발/부품 파편을 현재 원정에 연결했다. Blender/INK·실제 호스트 입력·음원 재생·저장 확인과 직접 조작/장시간 검수의 경계를 기록한다.

2026-09-12 [해적 비행 전투 첫 구현](production/139-pirate-flight-combat.md): 새 원정에 성간 감속 차단·항성계 내부 추격, 함포·실드·격퇴/도주·포드 인양·긴급 복구를 연결했다. FINCH는 비무장 운송 역할을 유지한다. Blender/INK와 현재 원정 확인, 기존 저장 보존 및 독립 포탑/전투정 후속 범위를 구분한다. 후속 UI는 첫 위험 안내 외 설명을 줄이고 선박 교신으로 표시한다.

2026-09-12 [지상 생물 보행·접지](production/142-ground-locomotion.md): 지상 5,130종에 이동 거리 기반 보행·발 접지·회전/정지·LOD 연결을 적용하고 Blender 다리 40종을 수정했다. 기존 저장 호환, 대표 88개 구조 렌더·실제 T4 교전과 개별 전종 검수의 경계를 기록한다.

2026-09-12 [토착 생물의 티어별 전투 강화](production/140-native-combat-tiers.md): 행성 T1~T5의 체력/피해와 유형별 기동·범위·연속 타격 간격, 동일한 호스트/표시 계산을 연결했다. 기존 남은 체력·무력화와 원산지/성향을 보존하며 초기 수치·실제 T4 교전 확인과 후속 범위를 구분한다.

2026-09-12 [생물별 지상 공격 고도화](production/138-native-ground-attack-patterns.md): 기존 공격형 155종에 실제 돌진·고정 착지 도약·지면 범위·두 번 베기를 연결했다. 기존 정면 근접 126종, 원산지·성향 보존과 실제 확인/후속 범위를 구분한다.

2026-09-12 [토착 생물의 지상 교전](production/137-native-wildlife-combat.md): 선공·영역 방어·반격·도주와 경고/근접 공격, 실드·엄폐·무력화 저장을 연결한다. 일반 지상 동물의 첫 범위와 사건/비행 등 후속을 구분한다.

2026-09-12 [지상전 전용 음원 후속](production/136-ground-combat-foundation.md): 중단됐던 다운로드를 마치고 총기 8계열·재장전·명중·실드 파괴 11종을 적용했다. 실제 재생·재장전 시간·메뉴 정지와 출력 녹음을 확인했으며 청감 평가는 남는다.

2026-09-11 [지상전 첫 고도화](production/136-ground-combat-foundation.md): 8개 총기 계열·T1~T3, 조준/탄창/재장전·낮은 자세, 제작·희귀도 드롭과 방벽/장갑 엄폐벽을 연결한다. [전체 전투 설계](game/27-ground-and-flight-combat.md)의 생물 교전·신규 사건·공중전 및 후속 제작 기능과 실제 구현/확인을 구분한다.

2026-09-11 [행성 날씨·드문 자연재해](production/135-planet-weather.md): 새 원정에 물비·T2 이상 산성비/뇌우, 차양·접지봉, 관측·지도·정화 연결을 추가했다. 위험 추첨은 25~40분 간격·25%, 위험 지속은 45~60초다. 기존 세계의 날씨는 소급 변경하지 않는다.

2026-09-11 [UI 공통화·실드 아이콘 정돈](production/131-ui-consistency.md): 상태 선 아이콘·게이지·수치 정렬과 공통 컨트롤, 모듈 희귀도/비용 표현을 정리했다. 적용 화면과 실제 확인 범위는 제작 기록을 따른다.

2026-09-11 [최적화·콘텐츠 순차 작업](production/128-performance-and-content-commits.md): 사용자 승인에 따라 단계별 구현·확인·개별 커밋을 진행한다. 현재 완료 범위는 소관 기록을 따른다.

2026-09-10 [간결한 항성계 이동과 연속 선회](production/45-stellar-flight-transition.md): 이동 중 단계명·남은 시간·중복 HUD를 줄이고 도착 이름만 표시한다. 목적 방향 안전 정렬과 항성계 교체 전후 선체·카메라 회전을 연결했다. 실제 확인 범위는 제작 기록을 따른다.

2026-09-10 [특이 식물·미생물 100종](production/123-xenoflora-100.md): 식물 60개·미생물 군락 40개를 추가해 동물 700 + 식물 185 + 미생물 115 = 기본형 1,000개로 확장했다. Blender·두 LOD·도감·자연 출현·스캔/표본·저장을 연결했다. [전체 추가 목록](game/25-xenoflora-catalogue.md)과 [티어별 확률 해석](game/09-discovery-research-and-ecology.md)을 따르며 기존 은하의 분포를 보존한다.

2026-09-10 [동물 300종·티어별 생물권](production/122-xenofauna-300.md): 30개 구조군의 Blender 기본형 300개·두 LOD·도감·스캔/채집을 연결했다. 새 은하에서 무생물 행성을 유지하며 티어별 정착 가중치를 높이고 기존 저장의 계통을 보존한다. [전체 구조 목록](game/24-xenofauna-catalogue.md), 실제 확인과 이동 AI의 경계는 제작 기록을 따른다.

2026-09-10 [지구 주시·Sol 시작 연출](production/20-galaxy-start-and-lobby.md): 새 원정의 실제 선체·카메라 후진과 여러 행성이 보이는 전경 선회, 연출 뒤 업무 안내·튜토리얼, 완료 저장과 이어하기 미반복을 연결했다. 실제 1인 창에서 확인했으며 다중 접속·전체 회귀는 실행하지 않았다.

2026-09-10 [SP02 기업 실물 식별](production/108-corporate-presence-sp02.md): Lotus 보급선·상자와 mine/CooperTech 로봇에 표식, 운영사/제조사 구분, E 조사·J 기업 기록·저장 호환을 연결했다. 실제 Blender/INK 렌더와 최소 지상 확인 범위는 제작 기록을 따른다.

2026-09-10 [쿠퍼테크 전환](production/106-coopertech-rebrand.md): 쿠퍼가 설립하고 이끄는 전투로봇 기술회사로 설정·CT 심볼·게임 표시를 교체했다. 과거 신봉 설정은 폐기하고 기존 사건 ID/진행은 보존한다.

2026-09-10 [기업 심볼 v1 · SP01](production/105-corporate-identity.md): 네 회사의 벡터 원본·워드마크·단색/소형 28개 출력과 실제 SVG 비교를 완료했다. 게임 실물/조사 연결은 SP02이며 Blender/Godot 적용 완료와 구분한다.

2026-09-10 [기업·우주 공간 커밋 계획](planning/16-space-corporations-commits.md): 심볼 고도화와 화성·항만·선박·시드 활동·사건을 SP00~SP11로 분할한다. 실제 단계 상태와 최소 확인 범위는 계획을 따른다.

2026-09-10 **설계 초안** — [기업과 살아 있는 우주 공간](game/23-corporations-and-space-presence.md): Lotus·Space Y·CooperTech·mine의 역할/심볼, 복원된 Space Y 관리 화성과 시드별 거점·무역 항로·선박·사건을 정리했다. 문서·벡터 심볼 시안이며 게임 구현 기록이 아니다.

2026-09-09 [현지 생물 사건 5유형](production/104-native-biological-incidents.md): 실제 서식종의 부품 수집·둥지 보호·지하·4배 거대·희귀 색 변이, 관찰/이동 조건과 보상·J 기록·저장을 연결했다. 실제 검수와 미확인 범위는 제작 기록을 따른다.

2026-09-09 [쿠퍼테크 전투로봇 외형](production/103-illuti-combat-appearance.md): 작은 위협 센서·경사 장갑·비대칭 무장으로 형태를 교체했다. INK 카툰과 기존 전투 규칙을 유지하며 실제 확인 범위는 제작 기록을 따른다.

2026-09-09 [5희귀도·전설 11효과](production/102-legendary-module-effects.md): 비전투 회복·실드 파쇄·잔여 낙하 피해 완충과 탐험/운반/전투 조건부 효과를 획득·장착·호스트 계산에 연결했다. 실제 확인 범위는 제작 기록을 따른다.

2026-09-09 [내장 모듈·실드 T1~T3](game/22-suit-modules-and-shields.md): 외형 변화 없는 6부위 랜덤 장비, 탐험 획득과 교전 실드 개발. 실제 확인은 [제작 기록](production/101-suit-modules-and-shields.md)을 따른다.

2026-09-09 [T1~T3 자유 배치·테라포밍 탭](production/102-free-terraforming-and-globe.md): 신규 세계에 면적 복원, 대기 구체·수질 저지대/침수·토양 분산·오염 구역 내부 처리와 네 시각화 레이어를 연결했다. 기존 저장과 실제 확인 경계는 제작 기록을 따른다.

2026-09-09 **초기 기획** — [자유 배치 테라포밍](planning/15-free-placement-terraforming.md): 고정 복원 포인트를 시설별 집중/분산·거리/지형 영향과 유효 복원 면적으로 대체하는 초안이다. 후속 승인으로 구현한 v3와 기존 저장 보존은 위 제작 기록을 따른다.

2026-09-09 [T3 유입원 제어·전문 생산·지역 복원](production/100-tier3-terraforming.md): 새 세계의 네 현장·가스/수질 두 유형, P3 제품 7종·전문 개조와 제어 장치, 설계도 사용권·국소 풍경·지도·정산을 연결했다. 두 문제의 런타임·실제 창/저장을 확인했으며 탐험 획득/정거장 판매는 별도 작업이다.

2026-09-09 **T1/T2 구현·T3 이후 기획** — [사건형 탐험 분류](game/21-exploration-incidents.md), [8종 기본형 제작·확인](production/99-exploration-incidents-t2.md): 신호·운반·전력 복구·파괴·쿠퍼테크 교전·지진 공동을 현재 원정에 연결했다.

2026-09-09 [탐험 발견 T1/T2 20종](production/97-exploration-discoveries-t2.md): 거주 마을 생성 제외·기록 이행, 시드 발견물·현장 조사·다양한 보상·J 기록을 현재 원정에 연결했다. T3 로스트 테크놀로지 설계도와 우주정거장 구매는 소관 기획에 반영했으며 이 작업의 구현 범위는 T2까지다.

2026-09-09 **탐험 기획** — [티어별 발견 50개 후보](game/20-exploration-discovery-expansion.md): 거주 마을 제거·고지능체 후속 고도화·고티어의 발견 수와 종류 증가를 반영했다. 전체 50종 중 T1/T2 20종과 마을 제외는 위 제작 기록을 따른다. 나머지 발견 후보와 T3 이후 사건 확장은 후속 설계다.

2026-09-09 [T3 테라포밍 구현 항목](planning/14-tier3-terraforming-implementation.md): 탐험·설계도 획득 콘텐츠를 제외하고 4현장 제안·가스/수질 유입원·P3 제품/전문 설비·현장 공급·지도·보상·저장의 T3-01~10 묶음을 정리했다. 후속 구현 범위와 검증은 위 T3 제작 기록을 따른다.

2026-09-09 [지역 테라포밍·지표 공급·Tab 지도](production/98-regional-terraforming-and-map.md): 새 은하의 T1 작은 사업·T2 세 현장, 독립 재고/전력/환경·국소 복원·중간 대금과 지질별 지표 군집을 연결했다. 기존 세계와 지하 배치는 보존한다. T3 제작소 설계도 잠금·등록 접점을 제공하며 획득 콘텐츠와 T3~T5 고급 지역 문제는 후속 범위다.

2026-09-09 [초대 코드·게임 내장 서버](production/96-local-invite-and-embedded-relay.md): 방 만들기 시 별도 설치 없이 로컬 서버를 자동 시작한다. Python/Docker 선택 실행·입장/재접속·작은 대기실을 확인했으며 플랫폼 연동·외부망·Windows 실기는 미확인이다.

2026-09-09 [부위별 보석 염색 메뉴](production/95-suit-dye-menu.md): I 염색, 부위당 보석 1개, 무료 기본색 복원과 세계 저장·승무원 색상 복제를 연결했다.

2026-09-09 [점진적 탐험복 외장·염색 기반](production/94-progressive-suit-appearance.md): 3계열 5단계 실제 외장과 6부위 도색 채널을 연결했다. 염색 메뉴는 후속 범위다.

2026-09-09 [선박 단말·빈 첫 착륙지](production/93-ship-terminal-and-empty-landing.md): L 호출을 선박 F 메뉴로 옮기고 자동 현장 창고·지상 연구/증강 장치 배치를 제거했다. 직접 지은 시설과 사용 중인 기존 창고는 보존한다.

2026-09-09 [강화 이미지·SVG·건설 비용 정렬](production/92-augmentation-art-and-cost-alignment.md): ImageGen 3개 계열 그림, SVG 12종, 한 단계 효과 표시와 건설 재료 중앙 정렬을 적용했다.

2026-09-09 [표본·일반 아이템 통합](production/90-unified-specimen-inventory.md): Q 채집을 I의 같은 배낭·화물로 연결하고 표본별 한 칸 수납과 실제 생물 상세를 제공한다. 기존 공동 표본과 연구/원산지를 보존한다.

2026-09-09 [Lotus 출항 지원·현장 보급](production/91-lotus-start-and-airdrop.md): 새 원정의 기초 원료 각 50개·공용 FINCH 1대, L 호출·보급선 투하·F 실물 수령·무인 행성 배송·저장을 구현했다. 기업 성장·독립·지구 구출은 [스토리 구상](game/19-lotus-story-and-support.md)으로 남긴다.

2026-09-09 [아이템 표시·강화 트리·작은 광맥](production/89-ui-growth-and-small-deposits.md): 슬롯 중앙 정렬/크기, 아이콘 비용과 빨간 부족 수량, I의 불필요한 개조 안내 제거, 12능력 트리와 새 은하의 광맥 분산을 적용했다. 기존 강화 단계와 기존 은하의 고갈 기록은 보존한다.

2026-09-09 [수면 품질 옵션](production/88-water-quality-options.md): 낮음/보통/최상을 분리하고 규칙적인 흰 점을 카툰 물결·반사 띠로 교체했다. 실제 바다 비교, 메시 비용과 물리 판정 유지 범위는 제작 기록을 따른다.

2026-09-09 [수영·물 상호작용](production/87-water-interactions-and-swimming.md): 기존 Blender 리그의 수영과 입·출수/보행/총격 물보라, ElevenLabs 5종, 수중 표현을 연결했다. 호스트 판정·고정 효과 한도와 실제 실행 확인 범위는 제작 기록을 따른다.

2026-09-09 [필드의 화면별 가려짐·모션 최적화](production/86-field-visibility-optimization.md): 지형·시설 오클루전과 생물/시설 시각 CPU 생략을 연결했다. 개인 거리 설정과 호스트의 충돌·권한 계산을 유지하며 실제 적용·확인 경계는 제작 기록을 따른다.

2026-09-09 [완전 침수 시설 사용 중단](production/85-submerged-facility-lockout.md): 시설이 상단까지 잠기면 발전·작업·사용을 중단하고, 기본 창고도 접근을 막는다. 작업과 재고를 보존하며 배수 후 기존 조건으로 재개한다.

2026-09-09 [가려진 선내·정적 미리보기 렌더 최적화](production/84-covered-world-and-preview-rendering.md): 외부 비행 뒤 메인 3D를 중단하고 정적 모델 이미지를 변경 때만 갱신한다. 실제 선내 복귀·미리보기 변경/애니메이션 유지 확인을 통과했다.

2026-09-09 [백그라운드 갱신·저장 최적화](production/83-background-update-and-save.md): 숨겨진 우주/닫힌 메뉴 갱신과 지상 지도 준비를 줄이고 주기적 저장의 직렬화·파일 처리를 작업 스레드로 옮겼다. 우주 콜백 4.20→0.004ms, 실제 이륙·지도/선내 복귀와 저장 순서·오류 확인을 통과했다. 전체 프레임의 60 FPS 보장은 아니다.

2026-09-09 [굴착·물 흐름·동굴 침수](production/82-physical-surface-water.md): 호스트의 물 양 계산, 통로 개방 후 유입·수위 상승, 수중 저항·부력과 저장·복제를 연결했다. 주변 셀만 계산하며 해상도·수원·차량/시설 제약은 제작 기록을 따른다.

2026-09-09 [정지 상태의 백그라운드 CPU·렌더링 조사](production/81-background-performance-audit.md): 지상에서도 숨겨진 우주 시각 갱신이 프레임당 3.4~4.2ms를 사용하는 것을 확인했다. 지도 준비·닫힌 화면 갱신·동기 저장과 픽셀 비용을 분리 계측했으며 후속 개선은 제안이다.

2026-09-09 [원경 타일·충돌 준비·지형 CPU 최적화](production/80-terrain-streaming-optimization.md): 원경 부분 교체, GPU 메시 재읽기 제거, 세로 열 높이 재사용을 적용했다. 같은 조건의 원경 CPU 115.7→28.0ms·관련 18개/현재 원정 11개 확인을 통과했으며 지상 60 FPS와 순간 지연은 미해결이다.

2026-09-09 [지표 풍경·바다와 하천](production/79-surface-scenery-and-hydrology.md): 기존 모델의 지질 군집·접지·일관된 바람·흔적·장소별 소리를 보완하고 시드 기반 내리막 하천과 해안선을 연결했다. 기존 지형과 성능 개선 변경은 보존하며 유체/전 행성 해수면 변화와 구분한다.

2026-09-09 [현재 원정 최적화·그래픽 설정 간소화](production/78-performance-and-simple-settings.md): 팝업 검색·지형 표본/설치·우주 배경·외곽선 비용을 줄이고 낮음/보통/높음 중심으로 설정을 정리했다. 실제 지상 정지 약 34.5 FPS·보행 약 29.2 FPS이며 순간 지연과 60 FPS 미달은 남아 있다.

2026-09-09 [현재 원정 성능 조사](production/77-performance-audit.md): 지상 보행·우주 화면의 프레임 저하와 반복 팝업 검색·지형 갱신·픽셀 처리 비용을 조사했다. 당시 조사 조건을 보존하며 후속 구현은 위 최적화 기록을 따른다.

2026-09-09 [지표 공간감·복원 풍경](production/76-surface-presence-and-recovery.md): 기존 모델을 유지하고 지역 환경에 따른 풀·나무 군락, 얕은 습윤 수면, 돌풍·흔적·시설 작업등과 환경음 레이어를 연결했다. 실제 렌더·재생과 물리/전 행성 복원 미구현 범위를 구분한다.

2026-09-09 [행성 진입·접지·하선](production/75-planet-entry-and-disembark.md): 접근 카메라·대기 조명, 제동·다리 압축, 해치/램프·캐노피와 캐릭터 하선, ElevenLabs 4종을 현재 착륙에 연결했다. 실제 확인 범위와 전환막·로컬 하선 표현의 한계는 제작 기록을 따른다.

2026-09-09 [우주 그래픽·사운드](production/74-space-visuals-and-sound.md): 대기·구름·천체 그림자·은하 배경·근접 파편·추진 연출과 선박/성간 이동/발견·위험 음향을 현재 비행에 연결했다. Blender 3종·ElevenLabs 5종을 제작했다. 실제 렌더/재생 신호 확인과 청감·다중 접속 미확인 범위를 구분한다.

2026-09-09 [UX03 성장·정비·교역](production/73-growth-refit-and-market.md): I/J를 열람 중심으로 정리하고 실제 증강/연구 장치에서 개조한다. 선체 슬롯·교체 비교, 교역 검색/판매 필터·단가/총액을 연결했다. UX01~UX03 개편 구현을 마쳤으며 검증 한계는 제작 기록을 따른다.

2026-09-08 [UX02 발견 도감·제작소·생태·항해 자원](production/72-discovery-factory-and-navigation.md): 전체 발견 검색/페이지·기록 보존, 제작 분류/고정 실행, 생태 단계, 조사 자원/거점 전체 조회를 적용했다. 실제 창 26개와 후속 화면 8개 확인 통과. UX03 성장 동선·정비/교역은 대기다.

2026-09-08 [UX01 자원 탐색·창고 이동](production/71-resource-browser-and-cargo.md): 없는 품목 숨김, 검색/분류/정렬, 이름·수량, 최대 이동량·사용처, 작은 창 배치와 투명 건설 카드를 연결했다. [전체 3차 개발 계획](planning/13-uiux-renewal-commits.md)의 도감/제작/항해 및 성장/정비는 후속이다.

2026-09-08 [자원 확장·조작 편의 UI/UX 조사](production/70-uiux-audit.md): 실제 화면과 코드에서 자원 탐색, 창고 이동, 작은 창 겹침, 기록 제한, 제작/연구 동선 등 13개 개선 항목을 정리했다. 개선안은 구현 전 제안이다.

2026-09-08 [아이템 미리보기·아이콘 투명화](production/69-transparent-inventory-previews.md): 3D 미리보기와 장비·보석/부품 이미지의 사각 배경을 제거하고 실제 아이템·제작·신체·증강 화면을 확인했다.

2026-09-08 [A01~A06 통합 플레이 확인](production/68-augmentation-research-playcheck.md): 증강·연구·시험기·실제 지하 보석→선박 분석과 저장을 확인하고 I 화면 위 가이드 겹침을 수정했다. 기존 저장 242개 파일은 변경되지 않았다.

2026-09-08 [A06 표본 분석·시제품](production/67-specimen-analysis-and-prototypes.md): 연구대 실물 표본·분석, 제작소 Mk.2 시험기 조립, I 장착/화물 운송과 J 공동 기록을 연결했다. 현장 시험·Mk.3 해금은 A07이다.

2026-09-08 [A05 공동 탐사 연구 원장](production/66-shared-expedition-research.md): 세계 공유 상태·이전 사용권·스캔/채집 증거·본인 표본 기여·분석 단계·원자적 저장과 제작 권한 검사를 연결했다. 표본 조작 화면은 A06이다.

2026-09-08 [A04 시각적 신체 증강](production/65-visual-body-augmentation.md): 장치 안 자기 캐릭터의 다리·팔·흉부 선택, 보석 클릭/투입 슬롯, 호스트 결과 연출, I → 신체 능력 열람을 연결했다.

2026-09-08 [은하 지도 확대 입체감](production/64-galaxy-map-depth.md): 확대용 Blender 별·지도 높이·성운 유지·같은 구역 회전과 3D 위치 클릭을 연결했다. 실제 확대/회전·작은 창·정지 렌더를 확인했다.

2026-09-08 [A03 선박 증강 장치·표본 연구대](production/64-crew-stations.md): Blender 실물 장치, 선내/착륙지 F 접근, 실제 장치 제공자 연결. 보석 투입 UI와 표본 연구 수행은 A04/A06에서 이어진다.

2026-09-10 [태양계 시작 가이드 변경](production/63-contextual-play-guide.md): WASD 이동 → Shift 가속 → 화성 스캔 → 성간 출발, 선행 단계 잠금·끄기 즉시 해제·캐릭터별 진행 저장과 작은 화면 편지 수정.

2026-09-08 [우주 화면 직접 항해·플레이 가이드](production/63-contextual-play-guide.md): 항성계 표식 조준/클릭/F를 첫 태양계부터 동일하게 안내하며, 캐릭터별 자동 표시·항상 표시·끄기를 제공한다.

2026-09-08 [A02 보석 소비·신체 증강 거래](production/63-gem-augmentation-transactions.md): 본인 보석 차감과 단계 증가를 한 번 저장하며 중복·저장 실패·장치 접근을 검사한다. 관련 32개 확인을 통과했다. 실제 장치·화면은 A03~A04 대기다.

2026-09-08 [초기 실행·원정 로딩](production/62-startup-loading.md): 별도 진행률 페이지·모델 백그라운드 읽기·첫 렌더 준비와 초기 항성계 중복 생성 제거. 실제 홈/새 원정·대기실 시작을 최소 확인했으며 장시간 성능은 미검증이다.

2026-09-08 [신체 증강·탐사 연구 커밋 계획](planning/12-augmentation-and-research-commits.md): 보석 소비·개인 성장 3종·우주선 장치·시제품/현장 시험·T3 해금·지상 확장을 A01~A09로 정리했다. [첫 구현 기록](production/62-character-augmentation-foundation.md)과 이후 대기 항목을 구분한다.

2026-09-08 변경: 초반 T2까지 기초 설계는 연구 구매 없이 사용할 수 있다. 재료·제작소 Mk.2 개조 등 실물 조건은 유지한다. 자동화는 필수 진행 단계가 아니며 로봇은 출고·재파견 후 대기한다. 플레이어가 자동(전체) 또는 해당 행성에서 발견한 광물 카드를 선택해 시작한다. R은 지정 광맥 작업 후 대기로 돌아간다. [현재 구현·검증·상위 해금 경계](production/61-early-access-and-explicit-robot-work.md). 아래의 기초 기술 구매·기본 자동 채광·필수 자동화 안내는 이전 이력이다.


2026-09-08 [이탈 FINCH 회수·스냅샷 분할](production/60-shuttle-recovery-and-snapshot-packets.md): P 승무원 창의 호스트 회수, 가방/장비/화물·재접속 보존, 프로토콜 3의 압축/900바이트 조각 전송과 지표 채널 분리를 구현했다. 관련 34개·실제 화면 9개·별도 ENet 두 프로세스 확인을 통과했다. 기존 은하 참가 호환도 수정했으며 6인 인터넷·장시간 성능은 미확인이다. 아래 회수/패킷 개선 미구현 표기는 이전 이력이다.

- [채광 로봇 2티어·시드 동굴 구현](production/46-seeded-caves-and-automation.md)
- [첫 원정 단계·행성 환경별 개척 제안](planning/09-first-expedition-and-environment.md)

2026-09-08 [공동 우주선·FINCH 화물 UI 통일](production/59-vessel-cargo-ui.md): 실제 선체·기능 카드, 기존 아이템창과 동일한 화물 격자·드래그·사용 칸 표시를 연결하고 두 선박의 실제 화면/거래를 확인했다.

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
| [Lotus 스토리·개척 지원](game/19-lotus-story-and-support.md) | 구현된 출항 화물·보급, 사용자 이야기 원안과 독립·지구 구출 미정 |
| [기업과 살아 있는 우주 공간](game/23-corporations-and-space-presence.md) | 기업 심볼·정체성, 복원 화성·시드별 거점/항로/선박/사건의 설계 초안 |
| [로봇·자동화](game/03-robots-and-automation.md) | 제작, 랜덤 등급·특성, 작업·운반·전력·고장 |
| [테라포밍·행성 판매](game/04-terraforming-and-sales.md) | 환경 상태, 설비 효과, 평가 등급, 매각 절차·가격 |
| [지역 테라포밍·지표 수급·행성지도](game/20-regional-terraforming-and-surface-supply.md) | T1~T3 지역 사업 구현·지표 군집·Tab 지도·설계도 접점; T4/T5 후속 설계 |
| [경제·기술·계승](game/05-economy-and-progression.md) | 탐사 투자·계약·매각, 기술 상점, 자산 회수·수송 |
| [탐험·이벤트·문명](game/06-exploration-and-civilizations.md) | 발견 종류, 보상, 선택과 장기 결과 |
| [우주 탐험·우주선](game/07-space-exploration-and-ships.md) | 항해·후보 선정·개발 권한·선체/모듈 성장·해적·사건 |
| [항해 중 해적 습격](game/28-pirate-interdiction.md) | 두 이동 구간의 해적 습격·원정선 방어/도주·인양, 독립 포탑/전투정 후속 |
| [오픈월드·지하](game/08-open-world-and-underground.md) | 지역·수직 탐험·굴착·발견 밀도·위험·재방문 |
| [행성 날씨와 자연재해](game/26-weather-and-natural-hazards.md) | T2 위험 기상·낮은 빈도·차양/접지·정화와 첫 구현/후속 후보 경계 |
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

- [홈 UI/UX 개편](production/58-home-ui-remake.md): 버튼 정렬·간결한 문구·설정/종료 분리와 실제 시작 화면 확인.

- [UI 밝은 배경 투명화·행성 티어 BGM](production/102-transparent-ui-and-planet-music.md): PNG 투명 재렌더·T1~T5 음악 제작·연결·확인 범위.

- [SP03 Space Y 복원 화성](production/110-restored-mars-sp03.md) — 신규 세계 복원 외형·운영 정보, 기존 저장 보존.

- [SP04 화성 항만·지구 물류항](production/111-orbital-ports-sp04.md) — 궤도 접근/정지·독립 기초 물자 교역·실제 Space Y 식별.

2026-09-10 SP05: [Space Y 무역선 운항·제작·확인](production/113-space-y-freighters.md).

2026-09-10 SP06: [Space Y 경비 편대·센서 확인·저장](production/114-space-y-patrol.md).

2026-09-10 SP07: [시드 기업 진출권·회사별 거점·행성 간 운항](production/115-seeded-corporate-regions.md).

2026-09-10 [SP08 기업 활동 흔적](production/117-corporate-activity-traces.md): Lotus 비콘·mine 집하/정비대·CooperTech 감시/봉인 실물, E 조사·공동 저장·지도/J 공개를 연결했다. 기존 은하 보존과 실제 확인 범위는 제작 기록을 따른다.

2026-09-10 [SP09 유실 화물 회수·선체 적재·항만 인계](production/118-freight-salvage.md): 실제 윈치/거치대·공동 저장과 단발 정산·지도/J 공개.

- [SP10 mine 작업장 정비·재가동](production/119-mine-maintenance.md) — 구현·모델·직접 운반·저장·확인.

- [SP11 CooperTech 우주 단서·지상 로봇 연결](production/120-coopertech-ground-clues.md) — 동일 ID·지도·실제 교전/회수·저장.

- [기업 우주 잔여 범위 완료·협동 확인](production/121-corporate-presence-completion.md) — SP10/11 커밋·3개 프로세스·재접속·동일 사건 종결.

- [8,000종·행성 독점 생태·50만 행성 작업](production/124-biota-8000-work.md) — 완성 카탈로그·유형별 리깅·원산지 배정과 T1/T2 현장·조류·가스 관측의 실제 확인 범위.
- [생물 형태 연구·유형별 리깅](production/125-biota-research-and-rigging.md) — 실제 생물 자료와 가상 생태의 구분, 구조별 골격·가중치·모션 제작 기준.
- [신규 생물 유형 색인](production/126-biota-type-index.md) — 동물 몸 조직·기관계, 식물 성장형, 미생물 군락형과 18개 환경별 제작 레시피 수량.

- [중앙 체형·눈과 얼굴 교체](production/129-biota-midpoint-silhouettes.md) — 교체 196종의 형태·얼굴·관절, T2 현장 검수와 작은 도감 표시 수정.
