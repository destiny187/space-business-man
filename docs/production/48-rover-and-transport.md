# 로버 제작·지상 운용·행성 간 운송

설계 기준은 [로버·운송](../game/16-rover-and-transport.md), 작업 구분은 [C13~C15](../planning/11-ground-commit-plan.md)이다. 전체 UI 재설계는 별도이며 실제 모델과 짧은 문맥 조작을 우선한다.

## C13 — 제작 자산

2026-09-08. Blender 5.2.1에서 SCOUT 2인승 밀폐형 바퀴 로버를 제작했다. 원본은 `art/blender/vehicles/scout_rover.blend`, 게임 모델은 `assets/models/vehicles/scout_rover.glb`다. `tools/build_scout_rover.py`로 재생성한다. 두 좌석·유리문, 전후 바퀴, 조향·서스펜션, 화물 덮개와 고정점 등 25개 동작/연결 노드를 제공한다.

Blender 렌더와 Godot 4.7.2 Forward+ / Metal의 INK v1 정면·후면·문/화물 개방·운전석 시야를 확인했다. 검수 이미지는 `media/rover/`, 실행 스크립트는 `tests/render_scout_rover.gd`다. 대시보드는 전방 시야 아래에 배치했다. 제작 자산 커밋에서 실제 게임에 미완성 제작 버튼을 노출하지 않는다.

ElevenLabs Sound Effects에서 주행 반복·시동·문·제동·적재 윈치 반복·고장 6종을 생성했다. 원음은 `audio/source/elevenlabs/`, 실제 WAV는 `assets/audio/`, 프롬프트·파일 해시·길이·가공 정보는 `audio/manifests/rover-sounds.json`에 보존했다. `tools/import_rover_audio.py`는 모노화·DC 제거·주파수 정리·루프 접합·음량 조정을 수행한다. 파일 신호와 길이를 확인했으며 청감 평가는 아직 하지 않았다. 실제 게임의 공간 재생 연결은 C14/C15에서 기록한다.
