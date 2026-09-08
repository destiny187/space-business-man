# 구형 그래픽 후속 16종 재제작

2026-09-08 사용자 요청으로 [우선 5종](51-industry-remodel.md)에 이어 남은 `legacy` 모델 16종을 재제작했다. [INK v1](06-rendering-quality-standard.md)의 검은 윤곽선·3단 명암과 [Blender 공통 규격](49-common-blender-art.md)을 유지한다. 이번 후속 목록은 시설 5종, 장비 3종, 발견물·자연물 8종이다.

[시설 전후: 이전](media/ink-followups/facilities-before.png) · [교체 후](media/ink-followups/facilities-after.png)

[장비 전후: 이전](media/ink-followups/equipment-before.png) · [교체 후](media/ink-followups/equipment-after.png)

[발견물·환경 전후: 이전](media/ink-followups/environment-before.png) · [교체 후](media/ink-followups/environment-after.png)

![시설 5종의 실제 INK 렌더](media/ink-followups/facilities-after.png)

## 모델과 게임 연결

| 분류 | ID | 재제작 내용 | 기존 사용 경로 |
| --- | --- | --- | --- |
| 시설 | `base` | 출입문·관찰창·계단/난간·통신 마스트·정비판 | 기존 캠페인 착륙 기지 |
| 시설 | `factory` | 열린 조립 공간·바닥 레일·상부 집게 구조·측면 설비 | 현재 원정 건설·로봇 생산, 기존 캠페인 |
| 시설 | `charger` | 바퀴 접점·가이드·상태 표시·전원 단말 | 현재 원정 건설·충전, 기존 캠페인 |
| 시설 | `solar` | 큰 태양광 모듈 12개·후면 지지대·받침·인버터 | 현재 원정 발전, 기존 캠페인 |
| 시설 | `reactor` | 고대 코어·억제 코일·지지 암·제어판 | 기존 캠페인 발전 |
| 장비 | `surveyor` | 새 채광 차체와 같은 바퀴·드릴, 탐광 센서 마스트·표본함 | 기존 캠페인 탐광 로봇 |
| 장비 | `guardian` | 동일 차체·별도 조준 포탑·쌍열 포신·방열 링 | 기존 캠페인 경비 로봇 |
| 장비 | `manual_tool` | 손잡이·흡입구·임펠러·피스톤·보호 레일 | 현재 원정 채집 장비, 기존 캠페인 수동 장비 |
| 발견물 | `ruin`, `microbe` | 맞물린 석조 유적과 유물, 연결 필라멘트·소포·핵이 구분되는 군집 | 기존 캠페인 발견물 |
| 발견물 | `animal`, `civilization` | 몸체·얼굴·발·감각 귀·꼬리, 주거·지붕·문·공동 신호탑 | 기존 캠페인 동물·문명 |
| 자연물 | `tree` | 굽은 줄기·가지·두께가 있는 잎·노출 뿌리 | 기존 캠페인 생태 회복 식생 |
| 배경 | `mesa_0`, `mesa_1`, `mesa_2` | 넓은 정상·갈라진 쌍봉·중앙 첨봉과 침식 지층 | 기존 캠페인 원경 암벽 |

현재 기본 진입은 `crew_expedition.tscn`이다. 기존 캠페인에만 있는 기지·원자로·탐광/경비 로봇·발견물·암벽을 새 원정 기능으로 연결했다는 뜻이 아니다. 동물은 기존 전신 움직임을 유지하며 새 보행 리그를 추가하지 않았다. 기지 문·제작소 집게·태양광 지지대도 구조 표현이며 새 개폐·조립·추적 애니메이션을 구현한 것은 아니다.

산업 모델에는 공통 크림·청록·구조색·주황 재질을 적용하고, 돌·식물·생물은 고유 재질을 보존했다. 검은 선은 모델 텍스처에 그려 넣지 않는다. Godot의 `FrontierInkStyle.attach()`가 깊이·법선을 이용해 화면에 합성한다. Blender Cycles 그림은 형태 검수용이며 게임의 선·3단 명암은 아래 Forward+ 그림으로 확인한다.

## 원본과 재생성

- 제작기: [`tools/build_ink_followups.py`](../../tools/build_ink_followups.py). `build_ink_industry.py`의 공통 기구 함수와 `ink_blender.py`·`ink_materials.json`을 재사용한다.
- 편집 원본: `art/blender/{ID}.blend`, 암벽은 `art/blender/landscape/{ID}.blend`. 개별 부품 상태로 저장한 뒤 가동 부모/불투명 재질별 정적 표면만 GLB에서 병합한다.
- 게임 파일: 기존 `assets/models/{ID}.glb`. 원점·전방·기초 규격과 가동 노드의 이름/변환을 유지한다. [교체 전 계약](media/ink-followups/original-contracts.json)과 최종 비용/검수 기록을 함께 보존한다.
- 미리보기: 같은 ID의 `assets/ui/previews/{ID}.png`와 INK 카탈로그를 실제 게임 렌더로 갱신한다.
- `build_assets.py`는 교체한 모델을 덮어쓰지 않는다. `build_landscape.py`의 기존 진입점은 새 암벽 제작기로 연결한다.

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ink_followups.py
# 수정한 모델만 재생성: 위 명령 마지막에 -- microbe 등 ID 추가
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh res://scenes/showcase/ink_followups.tscn
```

Godot 장면은 변경 16종의 단독·혼합 렌더와 미리보기를 만든다. `-- --before`는 현재 모델을 이전 비교 파일에 저장하므로 과거 자료 보존 시 사용하지 않는다. Blender 제작 중 Vector 길이 속성 호출 오류는 수정 후 Blender를 재실행했으며, 이미 출력한 모델은 보존하고 남은 모델부터 이어서 제작했다.

## 실제 확인과 한계

Blender 5.2.1 LTS Cycles와 Godot 4.7.2 Metal Forward+ / Apple M2에서 단독 16종을 확인했다. 기지 외장을 가린 내부 씰 크기, 군집 내부에 묻힌 핵·연결 필라멘트는 렌더를 보고 바로잡았다. 공통 셰이더·재질과 암벽용 지층 셰이더를 유지한다.

[혼합 주광](media/ink-followups/mixed-day.png) · [약광](media/ink-followups/mixed-shade.png) · [역광](media/ink-followups/mixed-backlight.png)

- 현재 원정 40건 통과: 착륙·채집·흡입기/조사/펄스 효과와 기존 ElevenLabs 음원, 태양광/충전기/제작소의 배치 고스트·가방 비용 건설, 실제 로봇 생산·배터리 충전, 960×640 메뉴 차단·저장. [흡입기](media/ink-followups/suction.png) · [배치](media/ink-followups/factory-ghost.png) · [충전](media/ink-followups/charging-960.png).
- 최종 미리보기 재가져오기 후 저장된 원정 복원·메뉴 3종의 실제 텍스처 픽셀 일치·재저장 5건 통과. 첫 실행은 이전 가져오기 캐시를 사용했으므로 이 후속 확인으로 갱신을 확인했다. [최종 건설 카드](media/ink-followups/construction-960-final.png).
- 기존 캠페인: 바퀴·드릴을 부모 Y축으로 회전하던 문제 2건을 재현하고 `rotate_object_local(Vector3.UP, ...)`로 고쳤다. 수정 후 15건 통과, 카메라 검수 스크립트도 rebuild 뒤 관찰 모드로 재전환해 실제 화면을 확인했다. [탐광 로봇](media/ink-followups/legacy-surveyor-working.png) · [경비 작전](media/ink-followups/legacy-guardian-operation.png) · [기지/환경](media/ink-followups/legacy-settlement.png).
- 기존 가동 노드 20개의 GLB 이름·위치·회전·크기를 원본 계약과 비교해 보존을 확인했다. 편집 부품·출력 메시·삼각형 수는 검수 JSON에 자산별로 둔다. 수량은 FPS 개선 실측이 아니다.
- 검수 스크립트에서 로봇의 `type` 대신 `model` 키를 읽도록 수정했고, 미리보기 확인 종료는 올바른 `session.close_session()`을 기다리도록 바로잡았다. 최종 실행 로그는 실패 0이며 이전 검수 도구 오류를 게임 결함으로 기록하지 않는다.

실행 검수는 `check_followup_play.gd`의 현재 원정 흐름과 `check_followup_legacy.gd`의 기존 캠페인 흐름으로 한정한다. 사용자의 저장과 분리한 검수 세계와 메모리 캠페인을 사용한다. 최종 실행 결과는 [검수 기록](media/ink-followups/verification.json)에 기록한다.

이번 후속 16종으로 등록된 `legacy` 목록은 소진된다. 다른 `visual-prototype`·`gameplay-prototype` 자산과 생물 도감 수백 종 전체의 최종 품질 승인은 별개다. 전체 회귀·장시간 성능/LOD·다중 클라이언트·Windows 실기는 실행하지 않았다. 기존 ElevenLabs 음원을 재사용하며 이번에는 새 음원 생성이나 음색 청음을 수행하지 않았다.

2026-09-08 후속: 행성·생물 검토는 [54번 선별 개선 기록](54-planets-and-life-art.md)에서 진행하여 생물 600개 검토·200개 개선/400개 유지 및 행성 23종의 실제 렌더 확인을 마쳤다.
