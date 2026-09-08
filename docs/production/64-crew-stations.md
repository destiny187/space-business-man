# A03 — 선박 증강 장치·표본 연구대

2026-09-08 [커밋 계획](../planning/12-augmentation-and-research-commits.md)의 A03을 구현했다. 기본 공동 우주선의 선내와 착륙지 측면에서 **실물 장치를 보고 F로 접근**한다. 이번 화면은 회전 가능한 장치 미리보기와 현재 개인 증강 기록이다. 자기 캐릭터 부위 선택·보석 투입은 A04, 표본 분석·시제품 연구 화면은 A06에서 연결한다.

## 모델과 배치

공통 `ink_blender.py`·`ink-industrial-v1` 재질을 사용했다. 크림색 외장, 청록색 처리부, 어두운 프레임, 주황색 손잡이로 기존 선박 설비와 맞췄다. 곡면 외장·가스켓·레일·렌즈·케이블·분리된 가동 부품을 Blender에서 제작했다.

| 장치 | 실물 구성 | 가동 노드 | 편집 메시 / 내보낸 표면 |
| --- | --- | --- | --- |
| 신체 증강 장치 | 열린 스캔 아치, 발판, 손잡이, 보석 처리부 | `Anim_ScanHead`, `Anim_GemTray` | 39 / 13 |
| 표본 연구대 | 표본 회전 받침, 고정 턱, 계측 암, 시료 홈, 계측 화면 | `Anim_SpecimenTurntable`, `Anim_OpticalArm` | 46 / 12 |

원본은 `art/blender/crew/*_station.blend`, 게임 모델은 `assets/models/crew/*_station.glb`다. 정적 표면 통합 전 원본을 저장하고 상호작용·보석·표본 소켓을 보존했다. 생성기는 `tools/build_crew_stations.py`, 자산 목록은 `stations_manifest.json`과 공통 모델·렌더 목록에 기록했다. 전면은 Blender -Y / Godot +Z다.

배치는 `data/crew_stations.json`이 소유한다. 선내 후방 좌우 `(±3, 0, 4.2)`에서 중심을 바라보며, 기존 좌석 뒤·중앙 화물함 옆 공간을 사용한다. 증강 아치는 기둥·발판·상부에 충돌을 나눠 열린 내부를 유지하고 연구대는 본체·계측 타워에 충돌을 둔다. 중앙 통로를 가로지르는 새 벽은 없다.

착륙 중에는 현재 선내 접근 구조를 대신하는 **선박 측면 서비스 장치**를 제공한다. 원정선 기준 `(8.1, 0, ±2)`에서 +X 방향을 보며, 해당 행성 지형 높이에 맞춰 바닥을 놓는다. Kestrel GLB의 X 범위 ±6.11m 바깥에 배치했다. 별도 시설 건설·재료 비용은 없으며 FINCH에는 생성하지 않는다.

## 연결

- 거리 3m 안에서 조준하고, 카메라에서 장치 소켓까지 다른 충돌체가 가리지 않을 때 F 대상을 표시한다. 장치 안내 중에는 다른 F 문구를 숨긴다.
- F로 장치 모델 미리보기·증강 기록을 열고 Esc로 닫는다. 메뉴 중 이동·장비·채집 입력은 기존 공통 메뉴 차단을 따른다. 멀어지거나 장치 공간을 떠나면 화면을 닫는다.
- 조준·열람 중 스캔 헤드/트레이와 표본 받침/계측 암이 움직인다. 실제 증강 가공이나 연구 성공을 의미하는 연출은 아직 없다.
- 기존 ElevenLabs `sfx_pickup_resource`의 0.6초 기계 클릭을 열람 시 -10dB로 재사용한다. 새 음원을 생성하지 않았다. 출처·용도는 `audio/manifests/crew-stations-reuse.json`에 기록했다.
- 호스트 `augmentation_station_provider`를 실제 장면 노드에 연결했다. 요청마다 현재 선내/행성·노드 존재·소켓 좌표를 조회하며 제거한 장치의 위치를 캐시하지 않는다. 선내와 서비스 장치는 같은 `ship:augmentation`과 기존 개인 원장을 사용한다.
- 호스트의 다른 행성 충돌 공간에도 주선 장치를 배치하고 선내 장치의 공간을 옮긴다. 이 경로의 실제 다중 접속 검증은 A08에서 남겨 둔다.

## 최소 확인과 한계

Blender 5.2.1 LTS의 Cycles 렌더와 Godot 4.7.2 Metal Forward+의 INK 렌더를 실제로 실행해 형태·재질·가동 부품을 확인했다. 실제 원정 장면에서 **15개 확인, 실패 0**을 기록했다. 선내 두 장치 F 진입, 960×640 미리보기, 도구 차단, 스캔 헤드 이동, 기존 음원 재생 상태, 실제 장치 제공자를 통한 A02 보석 거래, 착륙지 지형 준비·연구대 F 진입, 행성 문맥, 제거 직후 접근 거절을 포함한다.

최초 실행에서 UI 부모 참조 오류를 발견해 기존 탐험 화면의 부모 Control로 연결했고 같은 경로에서 수정 확인했다. 사용자 저장은 사용하지 않았다. 병행 중인 로딩·항해 안내 변경과 분리하기 위해 **A02 커밋 + 이 A03 변경으로 만든 `/tmp` 사본**에서 실제 원정 검사를 실행했다. 새 모델의 별도 렌더는 작업 저장소에서 실행했다.

실제 6인 동시 동선·원격 ENet·FINCH 왕복·장기 재접속·모든 시드 경사면은 확인하지 않았다. 기존 음원의 게임 재생을 확인했으며 새 가공/결과 음향 제작·최종 청음은 A04/A06 범위다. 보석 채집부터 증강 구매까지의 완주나 고티어 연구 해금 완료로 기록하지 않는다.

[실행 로그](media/crew-stations/interaction.txt) · [렌더 로그](media/crew-stations/render.txt)

![Godot INK 장치와 가동 부품](media/crew-stations/stations-ink-inspection.png)

![선내 증강 장치](media/crew-stations/augmentation-cabin.png)

![착륙선 측면 연구대](media/crew-stations/research-surface.png)

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_crew_stations.py
./tools/godot.sh --script res://tests/render_crew_stations.gd
./tools/godot.sh --script res://tests/check_crew_stations.gd -- --crew-ui-test --crew-folder=/tmp/crew-stations-a03
```
