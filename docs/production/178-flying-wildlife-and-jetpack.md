# 지표 비행 생물 교전과 T2 제트팩

2026-09-14 사용자 승인: 지표 비행 생물의 전투 AI를 구현하고, 점프 상태에서 Space를 다시 누른 채 유지하면 상승하는 장착형 제트팩을 T2 장비로 추가한다. 수영/잠수 조작과 수면 표현은 기존 기능이지만 수중 생물 전투는 이번 범위가 아니다.

## 연결 범위

현재 `surface_air`와 실제 지표 비행 경로를 가진 조류형 **140종**을 공통 호스트 전투 경로에 연결한다. 원산지·개체 ID·기존 메시·골격·이착륙/순찰 클립과 새 고속 모션을 유지한다. 성향은 종 시드로 고정되며 선공·영역 경계·피격 도주를 구분한다. 가스행성의 `atmosphere` 부유종, 이동 경로가 없는 구형 날개 모델과 수중종에 새 AI를 적용한 것으로 세지 않는다.

- 경고 후 플레이어의 실제 3D 위치로 접근한다. 지상·제트팩 공중 위치를 같은 호스트 위치로 판단한다.
- 공격은 준비 후 한 번 정한 방향으로 비행하며 구간을 잘게 나누어 접촉을 확인한다. 피해는 기존 실드/체력 경로를 사용하고 한 공격에서 같은 대상에게 중복 지급하지 않는다. 엄폐·지형·시설·착륙선 안전 구역을 검사한다.
- 막힘/빗나감/접촉 뒤에는 상승·이탈하고 재접근한다. 피격 도주형과 낮은 체력의 개체는 상승하며 거리를 벌린다. 목표가 추격 범위를 벗어나면 기존 순찰로 복귀한다.
- 무력화된 비행 개체는 중력으로 지표까지 떨어지고 마지막 위치를 보존한다. 저장·재개는 공격 진행을 초기화하며 남은 체력과 무력화를 유지한다.
- 총기 판정·스캔·표시·충돌체가 같은 전투 위치를 사용한다. 표시에는 호스트 시각을 이용한 보간을 적용한다. 실제 이동속도가 높으면 날개/몸통 모션도 빨라지며 모션을 이유로 게임 이동속도를 낮추지 않는다.

초기 접근 6.5m/s·공격 13m/s와 티어 가중, 42m 추격 거리·원산 위치 기준 최대 48m 고도 등은 `wildlife_combat.json`의 조정 가능한 초깃값이다. 전종별 공격 방식이 새로 제작된 것은 아니며 첫 범위는 공중 접근 접촉 공격이다. 원거리 골침 등 개별 종의 별도 전투 패턴은 확장 범위다.

## 제트팩 제작·장착·입력

`jetpack_2`는 강화 프레임 2·제어 회로 2·열전달 장치 2를 소모하는 T2 개인 장비다. 실제 제작 비용은 `equipment.json`을 따른다. I의 제작에서 만든 뒤 소유 장비에서 **등에 장착**한다. `back_slot`은 선택 필드이며 기존 번호 슬롯 5개와 총기를 유지한다. 해제·우주선/행성 창고·로버 적재 시 소유권과 등 장착을 함께 처리한다.

1. Space를 눌러 보통 점프한다. 처음부터 계속 누르는 것으로 추진이 켜지지는 않는다.
2. 공중에서 Space를 놓았다가 다시 누른 채 유지하면 상승한다. 놓으면 추진이 멈추며 다시 누르면 남은 잔량으로 재개한다.
3. 초기 추진 시간은 8초, 상승 최고속 8m/s, 착지 시 초당 추진 시간 2초씩 회복한다. 별도 착륙 제동으로 하강속도를 9m/s까지 제한한다. 설정은 `crew_locomotion.json`에 둔다.
4. 선내·차량·수영 중에는 추진하지 않는다. 메뉴/비활성 입력·만료된 입력·장비 해제로 추진을 유지하지 않는다. HUD의 잔량 막대와 동작 안내를 사용하며 공중 사격은 기존 총기를 사용한다.

공유 충돌 이동 함수에 같은 재입력/잔량 규칙을 넣고 입력 RPC에는 눌림 상태를 추가했다. 호스트가 소유 장비와 실제 접지 상태를 확인하며 클라이언트는 동일 규칙으로 예측·재조정한다. 캐릭터 등 모델·배기·소리는 호스트가 확인한 장착/추진 상태를 따른다.

## 아트·소리와 처리 범위

`tools/build_jetpack.py`가 공통 `ink_blender.py` 재질/곡면 규격으로 편집 가능한 원본과 GLB를 만든다. 원본은 `art/blender/equipment/jetpack_mk2.blend`, 게임 모델은 `assets/models/equipment/jetpack_mk2.glb`다. 원본 Cycles 검토와 Godot Forward+ INK 아이콘/실제 착용 검토를 구분한다. 등뼈 부착을 사용하고 두 배기 노즐의 효과가 추진 상태를 표시한다.

제트팩에는 기존 ElevenLabs `sfx_finch_turbine_v2.wav`를 작고 높은 톤으로 재사용한다. 원 생성 정보는 [74 음향 기록](74-space-visuals-and-sound.md)과 `audio/manifests/space-polish.json`을 따른다. 생물 경고·공격·피격에는 기존 ElevenLabs 생물 음원을 재사용한다. 신규 음원 생성으로 기록하지 않는다.

제작/장착은 기존 `equipment_craft`/`equipment_equip`의 해당 플레이어 장비·재고 거래 초안을 사용한다. 한 장비의 장착으로 전체 종/지형을 재생성하지 않는다. 누른 Space 상태는 기존 이동 발행에 포함하며, 공중 AI는 기존 주변 후보와 최대 활성 개체 한도 안에서 해당 개체만 갱신한다. 장애물 우회는 제한된 구간 검사와 국소 상승이며 전체 월드 경로 탐색을 추가하지 않는다. 저장 원자성·중복 요청 방지·호스트 피해 판정은 유지한다.

## 확인 기록과 남은 범위

- `check_flight_combat_jetpack.gd`: **23개 확인, 실패 0**. 실제 충돌체로 첫 점프 유지/공중 재입력·추진 해제·입력 차단·장비 해제·배터리 소진을 확인했다. 제작/소유권·번호 슬롯 보존, 공중 플레이어 접촉 피해·공격당 중복 방지·엄폐 차단·피격 도주·낙하/저장도 확인했다. 실제 원정에서 발견한 경고 회전의 ±π 경계 저장 오류를 수정하고 재현 검사를 포함했다. [규칙 로그](media/flight-jetpack/rules.log), [위치·피해 추적](media/flight-jetpack/rules.json).
- `check_flight_jetpack_play.gd`: Metal **Forward+ 실제 원정 20개 확인, 실패 0**. 시드 71503의 자연 원산지 T5 `biota_bilateral_mandibles_26`에서 실제 아이템 패널의 제작/등 장착 요청, 앱 점프 입력 경로·상승·추진음·해제, 기존 펄스 카빈의 공중 생물 공격/무력화, 저장·재개를 확인했다. 자동 확인은 테스트 입력을 사용했으며 물리 키보드 수동 플레이와 구분한다. 사용자 저장과 분리한 `/tmp/flight-jetpack-play`를 사용했다. [실행 로그](media/flight-jetpack/play.log), [제작·장착 화면](media/flight-jetpack/inventory.png), [상승](media/flight-jetpack/ascent.png), [접근 공격](media/flight-jetpack/attack.png), [무력화](media/flight-jetpack/down.png).
- 기존 `check_creature_fast_flight.gd`: **8개 확인, 실패 0**. 지상 대기/이륙/비행/착륙과 실제 변위 기준 빠른 날갯짓·일시정지를 유지한다. 운송된 외래종은 기존 `flight_pose`의 격리구역 대기 규칙을 유지하고 토착 생물 전투에 편입하지 않음을 추가 확인했다. [로그](media/flight-jetpack/fast-flight.log).
- 새 제트팩의 [Blender/Cycles 원본 렌더](media/flight-jetpack/blender.png), 게임 아이콘과 [Forward+ 등뼈 부착·상승 자세](media/flight-jetpack/worn-studio.png)를 확인했다. 실제 원정의 야간 손전등에 의한 밝은 착용 화면은 중립 조명 스튜디오 검토로 보완했다.
- 기존 ElevenLabs 추진음의 반복 범위가 0이라 지속 재생되지 않던 문제를 수정했다. 호스트가 확정한 추진 중 재생 상태와 [실제 SFX 녹음](media/flight-jetpack/runtime.wav)을 확인했다. 녹음은 12.096초, 48kHz 스테레오이며 [파형 검사](media/flight-jetpack/audio-check.json)의 피크는 21,909/32,768이다. 전종별 소리와 장시간 반복의 최종 청감 검수는 하지 않았다.

실제 원정 첫 성공 실행의 종료 시 ObjectDB 1개 경고가 있었다. 동일 동작의 상세 종료 진단에서는 재현되지 않았고 20개 확인을 다시 통과했다. [상세 로그](media/flight-jetpack/exit-diagnostic.log)에 기존 RGB8 이미지의 Metal RGBA8 변환 경고와 실제 종료 상태를 보존한다. 간헐적인 종료 경고의 원인을 확정한 것으로 기록하지 않는다.

전종 각각의 모든 변형·경사·복잡한 장애물 및 난이도 검수, 실제 6인/외부망 지연·손실, Windows 실기와 새 배포 파일 제작은 미확인이다. 장애물 회피는 국소 상승을 사용하므로 복잡한 천장/동굴용 3D 경로 탐색 완료를 뜻하지 않는다. 개별 종의 원거리 공격 패턴과 가스행성 항법·수중 생물 교전은 이번 구현 범위가 아니다.

재현 명령:

```bash
./tools/godot.sh --headless --script res://tests/check_flight_combat_jetpack.gd
./tools/godot.sh --headless --script res://tests/check_creature_fast_flight.gd
./tools/godot.sh --script res://tests/check_flight_jetpack_play.gd -- --crew-ui-test --crew-folder=/tmp/flight-jetpack-play
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/build_jetpack.py
./tools/godot.sh --script res://tests/render_jetpack.gd
```
