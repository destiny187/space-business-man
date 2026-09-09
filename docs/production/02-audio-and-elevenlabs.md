# 사운드·ElevenLabs 제작

2026-09-09 우주 음향 확장: ElevenLabs에서 반응로·FINCH 터빈·고출력 배기 3종과 발견/위험 음악 2곡을 생성하고 현재 비행에 연결했다. 선내/외부 믹스·성간 이동 단계·메뉴 정지를 적용했다. [제작·게임 재생 확인·청감 미확인](74-space-visuals-and-sound.md)과 [생성 기록](../../audio/manifests/space-polish.json)을 따른다.

## 확정 요구사항

사운드 제작에 **ElevenLabs**를 활용한다. 아래는 초기 제작 설계다. 2026-09-06 현재 **16종을 ElevenLabs 웹에서 실제 생성하고 게임에 연결**했다. 원본 WAV와 게임용 편집본, 프롬프트·웹 생성 기록·선택본·해시는 [제작 이력](../../audio/manifests/elevenlabs.json)에 보관한다. 길이·샘플레이트·루프·환경 전환·재생은 68개 항목으로 확인했다. 음악의 범위와 보컬·언어·성우 구성은 미정이다.

## 청각 방향 — 설계 제안

2026-09-07 추가 확정 및 적용: 우주용·행성용 기악 배경음악을 각 2분으로 제작하고 연결했다. 여성 AI 음성은 후속 사용자 지시로 제외했다. 제작 이력·재생 조건·확인 범위는 [탐험 배경음악](39-music-and-ship-ai.md)을 따른다. 위의 음악 범위 미정 기록에 우선한다.

초기 행성은 바람과 장비 소리 중심으로 비어 있는 느낌을 준다. 자동화가 늘면 모터·운반·설비 소리가 겹치며 생산 규모가 들리고, 테라포밍 이후에는 물·식생·생물 소리로 환경 변화가 느껴지게 한다.

로봇은 작은 전자음과 기계 동작음으로 개성을 표현한다. 보이스 안내를 추가해도 반복 작업마다 긴 대사를 재생하지 않는다. 중요한 경고는 소리와 화면 표시를 함께 제공한다.

## 우선 제작 목록 — 설계 제안

| 오디오 ID | 용도 | 형식·변형 요구 | 단계 |
| --- | --- | --- | --- |
| `sfx_mine_hit_metal` | 금속 광맥 타격 | 짧은 단발음, 3~5개 변형 | MVP |
| `sfx_mine_break` | 자원 노드 고갈 | 파손·수집 완료 단발음 | MVP |
| `sfx_pickup_resource` | 자원 획득 | 짧고 반복에 피로하지 않은 소리 | MVP |
| `sfx_build_place` | 건축 확정 | 조립·체결 단발음 | MVP |
| `sfx_build_invalid` | 배치 불가 | 절제된 UI 단발음 | MVP |
| `sfx_robot_move` | 로봇 이동 | 모터 루프, 속도별 조절 | MVP |
| `sfx_robot_work` | 로봇 채광 | 작업 루프·정지 꼬리 | MVP |
| `sfx_robot_charge` | 충전 | 저자극 루프·완료 알림 | MVP |
| `sfx_factory_complete` | 로봇 제작 완료 | 짧은 성공음, 등급 연출 후보 | MVP |
| `sfx_terraform_active` | 테라포밍 설비 | 팬·압축기 루프 | MVP |
| `amb_barren_wind` | 초기 황무지 | 환경 루프 | MVP |
| `amb_restored_nature` | 환경 정착 후 | 물·바람·생태 루프 | MVP |
| `ui_discovery` | 유적 발견 | 신비로운 짧은 알림 | MVP |
| `ui_planet_sold` | 행성 판매 | 정산 성공음 | MVP |
| `vo_robot_notice` | 로봇 상태 음성 | 짧은 안내, 자막 동반 | 확장 |
| `sfx_creature_*` | 야생동물 | 종·행동별 변형 | 확장 |
| `sfx_combat_*` | 전투·문명 충돌 | 전투 설계 확정 후 | 확장 |

MVP 개발 초기에는 채광·건축·로봇 작업·황무지 환경·매각 소리부터 적용한다. 표의 수량은 생성 완료 수량이 아니다.

## ElevenLabs 생성 과정 — 설계 제안

1. 실제 게임 행동과 필요한 소리 길이·반복 여부를 먼저 정한다.
2. 사용 가능한 ElevenLabs 연결·API·생성 기능과 출력 옵션을 생성 단계에서 확인한다.
3. 같은 용도에 여러 후보를 생성하고 듣는다. 실제로 사용 가능한 옵션만 기록하고 제공되지 않는 시드·루프 보장을 가정하지 않는다.
4. 원본을 보관하고 앞뒤 무음·클릭·불필요한 잔향을 정리한 게임용 버전을 만든다.
5. 반복음은 이음새를 편집하고 여러 번 반복해 듣는다. 단발음도 연속 재생 시 피로도를 확인한다.
6. Godot 오디오 정의에 연결하고 거리·음량·동시 재생·변형을 설정한다.
7. 플레이 중 채광·로봇·설비가 함께 들리는 상태에서 검수한다.

접근이 불가능한 경우 프롬프트와 필요한 파일 목록을 준비하고 상태를 ‘미생성’으로 유지한다. 생성 결과를 받지 않았는데 완료로 기록하지 않는다.

### 프롬프트 초안

**금속 채광 단발음**

> A single compact futuristic mining tool striking an iron-rich rock. Crisp mechanical impact, gritty mineral fragments, a short metallic resonance. Stylized science-fiction game sound, satisfying and clear. Dry recording, no speech, no music, no background ambience. About one second.

**보급형 채광로봇 작업 루프**

> A small industrial mining robot operating a compact drill. Rhythmic servo motion, controlled electric motor, granular rock cutting. Friendly utilitarian science-fiction character, close and dry. Steady texture suitable for loop editing, no speech, no music, no dramatic changes. About six seconds.

**초기 황무지 환경음**

> Wind moving across a barren alien moon, fine dust brushing rough stones, distant low atmospheric rumble. Spacious and restrained, with room for foreground machinery. No creatures, no voices, no music, no sudden impacts. A consistent ambience suitable for loop editing. About twenty seconds.

**행성 판매 완료음**

> A short futuristic business transaction success sound. Clean electronic confirmation followed by a warm, modest celebratory shimmer. Clear ending, no speech, no background music. About two seconds.

길이는 의도 전달용이며 생성 서비스의 실제 지원 범위에 맞춰 조정한다. ‘루프에 적합한 소리’ 요청만으로 이음새가 완성됐다고 간주하지 않는다.

## 파일과 생성 기록 — 설계 제안

```text
audio/
  source/elevenlabs/       # 내려받은 원본
  manifests/              # 생성·선정·편집 기록
우주-비즈니스/assets/audio/
  sfx/
  ambience/
  voice/
  music/                  # 음악 범위 확정 후 사용
```

게임 파일 예시는 `sfx_mine_hit_metal_01.wav`로 둔다. 짧은 효과음은 WAV, 긴 환경음은 검증한 압축 형식을 제안한다. 실제 샘플레이트·채널·인코딩은 가져오기와 청취 확인 후 통일한다.

기록 필드: 오디오 ID, 사용처, 프롬프트, 생성일, 사용 서비스·모델·설정(확인 가능한 항목), 원본 경로, 게임 파일 경로, 길이·채널, 편집 내용, 변형 번호, 선정 상태, 배포에 적용되는 사용 조건 확인 기록. 계정 비밀키는 기록에 포함하지 않는다.

## 게임 내 믹스 — 설계 제안

- 버스는 Master, SFX, Ambience, UI, Voice, Music으로 구분하고 음량 조절을 제공한다.
- 현장 장비·생물은 거리와 방향을 반영하고, UI·사업 안내는 명료하게 들리도록 별도 처리한다.
- 같은 소리의 동시 재생 수와 최소 재생 간격을 제한한다. 멀리 있는 수십 대의 로봇을 모두 같은 크기로 재생하지 않는다.
- 짧은 타격음은 변형·작은 피치 차이를 사용할 수 있지만 핵심 확인음의 의미는 유지한다.
- 루프는 시작·정지 때 부드럽게 전환하고, 일시정지·매각·장면 이동 시 남는 소리를 정리한다.
- 출력 클리핑, 큰 음량 차이, 긴 반복 피로, 헤드폰에서의 위치감, 음소거 상태의 시각적 안내를 확인한다.

## 1.1 동작 연계

추가 API 생성 없이 기존 ElevenLabs 음원 16종을 사용한다. `sfx_robot_work`의 별도 반복 재생기를 M-02 흡입 상태와 연결하고 음량·피치를 조정한다. 펄스는 `sfx_combat_pulse`, 채집·고갈은 기존 타격·파괴음을 사용한다. 메뉴에서는 흡입 루프를 멈추고 종료 시 스트림을 해제한다. 원본 WAV와 생성 이력은 보존한다.

## 탐험 확장의 준비 목록 — 미생성

아래는 설계용 신규 목록·프롬프트 초안이며 이번 작업에서 ElevenLabs 생성·청취·게임 적용을 하지 않았다. 기존 16종과 별도다.

| 오디오 ID | 용도·프롬프트 초안 | 재생 조건 |
| --- | --- | --- |
| `amb_ship_interior` | 작은 탐사선 내부, 낮은 환기·차체 진동·절제된 전자음, 음악·대사 없음 | 선내 루프; 엔진 부하·생물실 전력에 맞춘 층 |
| `sfx_orbital_scan` | 짧은 관측 펄스 뒤 서로 다른 확인음, 긴장 과장 없이 정보가 모이는 느낌 | 미확인·자료 확보·현장 확인의 다른 상태 |
| `amb_cave_thermal` | 넓은 암석 동굴의 열수·낙수·낮은 진동, 급격한 공포음 없음 | 동굴 크기·기체·수위에 맞춘 환경 층 |
| `sfx_lithotherm_feed` | 무거운 광물 외피 마찰, 천천히 씹는 암석, 잔잔한 열 분출 | 바위형 사례 섭식·활동; 군집 동시 재생 제한 |
| `ui_habitat_warning` | 거칠지 않은 짧은 이중 경고음, 긴 꼬리 없음 | 생물실 조건 이탈, 원인 텍스트·위치 동반 |
| `sfx_first_contact` | 낯선 음색의 짧은 패턴과 응답 여백, 인간 언어·음악 없음 | 문명 사례별 접촉; 의미는 시각 기록으로도 제공 |

진공 외부의 사건은 선체 진동·센서·통신 또는 명시한 게임용 효과로 전달한다. 대기·밀폐 구획·선내·수중·지하에 맞는 차폐·잔향을 구분하고 경고는 청각에만 의존하지 않는다. 구체적인 물리 음향 모델은 제안이며 신규 에셋 생성 시 기존 프롬프트·원본·버전·반복·음량 검증 절차를 따른다.

## 현재 원정의 기존 음원 복구

기존 ElevenLabs 16종의 원본/편집본은 보존하고 `FrontierExpeditionFeedback`에서 현재 원정의 실제 작업·로봇/시설 상태와 연결한다. 새 음원을 생성한 작업은 아니다. 재생 조건·검증·미생성 범위는 [기본 플레이 품질 복구](19-play-quality-restoration.md)를 따른다.

## 2026-09-07 우주 탐험 사운드 보완

깊이별 항성계 진입 5종·스캔 진행/완료·엔진·고속 전환·감속·항성 경고 등 ElevenLabs 11종을 추가했다. 프롬프트·신호 편집·게임 연결·검증 범위는 [우주 탐험 경험](34-space-experience.md#추가-요청--elevenlabs-사운드), 원본/편집본 기록은 [생성 매니페스트](../../audio/manifests/space-experience.json)를 따른다.

## 2026-09-07 — 개인 흡입과 표면 조사 믹스

개인 채집기의 금속 타격/드릴 루프를 기존 ElevenLabs 팬·압축기 `sfx_terraform_active`로 교체하고, 조사에는 `sfx_robot_charge`를 별도로 연결했다. 신규 생성 없이 강도/진행별 피치·음량을 적용했다. [소관 제작 및 실제 재생 확인](40-field-tool-feedback.md).

2026-09-07 정거장 교역에는 기존 ElevenLabs 진입·획득·제작 완료·실패·기계 반복 음원을 재사용했다. 호스트 거래 결과 후 재생하고 거래창 종료 시 환경음을 중단한다. 신규 생성은 없으며 [매핑 기록](../../audio/manifests/space-station-reuse.json)과 [실행 검증](42-space-stations-and-hulls.md)을 따른다.

2026-09-09 사용자 요청: 행성 BGM을 T1~T5 각 2분 기악곡으로 구분한다. 티어가 높아질수록 리듬·음색·화성의 긴장감을 높인다. [제작 및 적용](102-transparent-ui-and-planet-music.md), [생성 이력](../../audio/manifests/planet-tier-music.json)을 따른다.
