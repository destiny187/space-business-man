# 일루티 전투로봇 — 위협적인 외형

2026-09-09 사용자 요청. 카툰 렌더링을 유지하면서 귀여운 전투로봇의 형태를 더 무섭게 바꾼다. [INK v1](06-rendering-quality-standard.md)과 [공통 Blender 규격](49-common-blender-art.md)을 따른다.

## 교체한 형태

- 큰 사각 센서 머리와 둥근 주황 어깨를 작은 매립 센서·각진 눈썹 장갑·좁은 붉은 광학부·넓은 경사 어깨로 교체했다.
- 밝은 크림/청록 작업용 외장을 일루티 전투형의 흑연색 장갑·금속 마찰면·산화 적색 식별판으로 바꿨다. 공통 구조색·금속·안전 주황 재질과 베벨 함수를 재사용한다. 제조사 전용 도장색은 다른 로봇 재질에 영향을 주지 않는다.
- 아래로 좁아지는 흉부, 보호 목깃, 분절 복부, 긴 정강이 장갑·유압축, 한쪽 이중 포신과 반대쪽 집게형 손으로 기능과 위협 실루엣을 구성했다. 포신 2개는 외형이며 발사 횟수·피해를 늘리지 않는다.
- 캐릭터 높이 약 2.9m, 바닥 원점, 기존 `Anim_Torso`·두 다리·두 팔·`Anim_Weak` 6개 가동 노드와 반응로 약점 위치를 유지한다. 휴면/파괴 시 포신이 바닥에 닿는 부분은 상체 하강량을 0.4m→0.3m로 조정했다.

## 원본·출력

- 편집 가능한 원본: `art/blender/incidents/robot.blend`.
- 게임에서 기존 경로로 교체: `assets/models/incidents/robot.glb`.
- 생성기: `tools/illuti_robot.py`; 기존 `build_exploration_incidents.py`가 호출하므로 전체 사건 재생성 시에도 이 형태를 유지한다.
- `--robot-only`로 로봇만 내보내고 검수한다. `--robot-only --render-only`는 원본/GLB를 다시 쓰지 않고 Blender 확인 이미지만 만든다.
- GLB는 가동 부모/재질별 31메시·23,188삼각형·572,136바이트다. 편집 원본은 부품을 분리하고 게임 출력만 공통 규칙으로 병합했다.
- 게임의 발견 카드 이미지와 `render_assets.json` 제작 상태를 갱신했다.

## 확인 범위

Blender 5.2.1 LTS에서 원본 저장·GLB 출력·Cycles 형상/법선 렌더를 확인했다. 좌우 대칭 장갑의 면 법선 방향을 정리하고 전체 발끝이 프레임에 들어오도록 촬영을 수정했다. 수정 때 Blender를 재실행했다.

Godot 4.7.2 Metal Forward+의 실제 INK 셰이더로 전면·후면·휴면을 렌더링했다. 굵은 검은 윤곽, 단계형 장갑 명암, 붉은 센서와 반응로 노출 구분을 확인했다. 포신 접지 보정은 이 휴면 렌더에서 확인했다.

`check_suit_module_play.gd`의 `--crew-ui-test --crew-folder=/tmp/suit-module-play --legendary-review --robot-art-review`로 자연 생성 T3 일루티 기동·실드/사격·실제 무기 조준·파괴·F 부품 회수·저장의 22개 확인을 통과했다. 장소 이동과 시작 장비는 격리 검수 준비값이다. 기존 기동/사격/피격 음원 연결을 유지했으며 신규 음원 생성 또는 사람의 청감 평가를 주장하지 않는다.

[Blender](media/illuti-remodel/blender.png) · [INK 전면](media/illuti-remodel/godot-front.png) · [후면](media/illuti-remodel/godot-rear.png) · [휴면](media/illuti-remodel/godot-dormant.png) · [실제 교전](media/illuti-remodel/field-combat.png) · [파괴/회수](media/illuti-remodel/field-destroyed.png).

작업용 로봇의 외형, 전투 수치, 약점 판정, 저장 형식과 사건 보상은 이번 외형 변경으로 바꾸지 않았다. 전체 원정 완주·다중 클라이언트·Windows·장시간 성능 검증은 이번 최소 확인에 포함하지 않았다.
