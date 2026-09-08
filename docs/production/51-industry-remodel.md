# 채광 로봇·환경 시설 우선 재제작

2026-09-08 [공통 제작 규격](49-common-blender-art.md)의 다음 순서인 채광 로봇과 대기·열·물·생태 시설 5종을 재제작했다. [INK v1](06-rendering-quality-standard.md)의 검은 윤곽선·3단 명암, 공통 산업 재질과 기존 게임 ID를 유지한다. 전체 구형 자산 교체 완료와는 구분한다.

![우선 5종의 실제 Godot Forward+ 렌더](media/ink-industry/industry-after.png)

[교체 전](media/ink-industry/industry-before.png) · [교체 후](media/ink-industry/industry-after.png) · [SCOUT·창고·자연물 혼합 주광](media/ink-industry/mixed-day.png) · [약광](media/ink-industry/mixed-shade.png) · [역광](media/ink-industry/mixed-backlight.png)

## 제작 내용과 연결 계약

| 자산 | 변경한 형태 | 유지한 게임 연결 |
| --- | --- | --- |
| `miner` | 둥근 고무 타이어·구동 휠 전체 분리, 센서 헤드·렌즈, 관절 연결부·유압 호스·드릴 절삭날, 화물함·정비면 | Blender -Y / Godot +Z 전방, 바퀴 6개 이름·회전축, `ToolRotor`, 기존 드릴 끝 수집 지점 |
| `atmosphere` | 분리탑·교체식 필터·배기 후드·덕트·보호 테두리가 있는 흡기 팬 | 3.6m 기초, `Anim_Fan_Process` 위치·세로 회전축 |
| `thermal` | 넓은 방열판·상하 헤더·순환 배관·별도 팬 | 같은 기초, `Anim_Fan_Process` 위치·회전축 |
| `water` | 저장 탱크·수위창·필터·연결 배관, 가이드 레일과 실제 피스톤 | 같은 기초, `Anim_Piston_Process` 위치·상하 이동 |
| `biolab` | 관찰 유리·배양 식물·보호 기둥·양액통·외부 교반 구동부 | 같은 기초, `Anim_Agitator_Process` 위치·회전축 |

로봇의 암·센서 목·서스펜션은 구조 표현이다. 새로운 관절 추적이나 지형별 서스펜션 시뮬레이션을 추가한 것은 아니다. 배양 식물은 장치 내부의 시각 표본이며 새로운 생물 종이나 성장 규칙이 아니다. 기존 호스트의 실제 작업 상태에 따라 드릴·바퀴·팬·피스톤·교반부를 재생한다.

## 원본과 재생성

- 제작기: [`tools/build_ink_industry.py`](../../tools/build_ink_industry.py). `ink_blender.py`와 `ink_materials.json`을 사용한다.
- 원본: `art/blender/{miner,atmosphere,thermal,water,biolab}.blend`. 개별 부품을 보존하고 저장한 후 GLB에서 같은 가동 부모·재질의 정적 메시만 병합한다.
- 게임 출력: `우주-비즈니스/assets/models/`의 같은 ID. 기존 카탈로그·건설 카드·환경 HUD가 참조하는 미리보기 5장도 실제 INK 렌더로 교체했다.
- 형태 상태: `render_assets.json`의 해당 5종만 `ink-family-remodeled`로 변경했다. 원본·출력 수량·피벗은 `art/blender/manifest.json`, 시설 가동부 제작 경로는 `ground-motion-manifest.json`에서 추적한다.
- 구 생성기 `build_assets.py`는 교체 모델을 덮어쓰지 않는다. `build_facility_motion.py`도 새 제작기에 들어 있는 가동부를 중복 삽입하지 않는다.

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ink_industry.py
# 필요한 자산만 재생성할 때 마지막에 -- water 등을 지정한다.
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh res://scenes/showcase/ink_industry.tscn
```

Blender 보조 렌더는 `media/ink-industry/*-blender.png`에 둔다. 위 Godot 장면은 변경 5종의 단독·혼합 촬영과 도감 갱신용이다. 캠페인의 낮밤·성능 실측 장면은 아니다. `-- --before`는 교체 전 자료를 만들 때만 사용하며 현재 모델로 실행하면 기존 비교 자료를 덮어쓴다.

## 확인 기록

Blender 5.2.1 LTS의 Cycles와 Godot 4.7.2 / Metal Forward+ / Apple M2에서 원본 조립·가동부 분리, 실제 INK 렌더와 생태 관찰 유리를 확인했다. 첫 Blender 검수에서 팬 가림·조작판 지지대 누락·덕트 끝 연결을 수정하고 해당 시설만 다시 출력했다. Blender 재실행 후 최종 원본과 GLB를 갱신했다.

현재 `crew_expedition.tscn` 경로에서 기존 검수 도구를 필요한 범위만 실행했다. 사용자의 저장과 분리한 `/tmp/ink-industry-robot-review`, `/tmp/ink-industry-facility-review`를 사용했다.

- `check_robot_work.gd`: 새 로봇 생성·실제 드릴 회전·호스트 광맥 방향·드릴 끝 수집 위치·자원 채집·ElevenLabs 위치 음원·저장 7건 통과. [실제 채광 화면](media/ink-industry/robot-drilling.png).
- 종료 후 비워진 `session.latest.crew`를 지표 장면이 읽는 오류를 발견했다. `crew_surface_scene.gd`에 세션 비활성/스냅샷 없는 경우의 갱신 가드를 추가했다. 그 뒤 시설 실행의 저장·종료 로그에서는 같은 오류가 발생하지 않았다.
- `check_facility_operation.gd`: 네 장치의 처리·가동부·위치 음원, 얼음 부족·수동 정지·전력 부족·저장을 확인했다. [대기](media/ink-industry/atmosphere-working.png) · [열](media/ink-industry/thermal-working.png) · [물](media/ink-industry/water-working.png) · [생태](media/ink-industry/biolab-working.png) · [재료 부족 정지](media/ink-industry/water-waiting.png).
- 시설 실행 29건 중 목표 도달 검사 1건이 실패했다. 검수용 목표값을 정수로 넣어 협동 처리의 실수형 정규화가 사전 비교에서 변화로 집계된 문제였다. 실제 환경값과 같은 실수형으로 검수 자료를 바로잡고 `--facility-stopped-review`로 저장 읽기·목표 도달 정지 2건만 재확인해 통과했다. 시설 전체 실행을 반복하거나 최초 실행을 실패 0으로 기록하지 않는다.
- 실제 SFX 버스 6.41초 녹음의 피크 -16.92dBFS, RMS -30.84dBFS, 클리핑 0샘플을 확인했다. 기존 ElevenLabs 음원 재생 확인이며 새로운 음원 생성이나 음색 청음은 하지 않았다.

[출력 비용·검수 기록](media/ink-industry/verification.json): 로봇 33메시/78,788삼각형, 대기 8/21,796, 열 8/18,564, 물 9/22,532, 생태 12/34,112다. 원본의 개별 편집 부품과 내보낸 메시 수를 구분한다. 가동 피벗은 병합 전후 변환이 같고 GLB에도 같은 이름·축으로 남는다. 이 수치는 자산 비용이며 게임 FPS 실측이 아니다.

## 남은 범위

이 작업 다음 순서였던 제작소·충전기·기지와 다른 구형 장비·배경·발견물 16종은 [후속 제작](52-legacy-art-completion.md)에서 모두 교체했다. 아래 미확인 범위는 우선 5종 작업 당시 기록이며 최신 실행 확인은 후속 문서를 따른다. 이미 승인 형태를 사용한 자산은 중복 재제작하지 않는다. 생물 수백 종의 형태·동작·군집 검토, 장거리 LOD·장시간 성능, 전체 착륙→수동 채집→건설 반복·960px 메뉴·재접속·다중 클라이언트 실기와 음색 청음은 이번 재제작에서 다시 확인하지 않았다.
