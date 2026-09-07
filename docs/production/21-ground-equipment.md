# 지상 아이템창과 휴대 장비 분리

2026-09-06 현재 원정의 아이템창·제작·5개 장착 슬롯·등급 채광·독립 지형 변환기·펄스 카빈을 추가했다. 요구사항과 규칙의 원본은 [아이템·제작·장착](../game/13-inventory-and-equipment.md)이다.

## 구현과 제작

- `FrontierEquipment`와 `data/equipment.json`: 개인 세계 장비·조립 키트·7개 설계도·장착·검증. 기존 사업 배낭에서 재료를 차감한다.
- `FrontierEquipmentPanel`: 재화 아이콘, 공동/개인 보관 위치, 실제 모델 카드, 제작·소유 장비 탭, 번호 슬롯.
- 기존 `crew_authority`, `crew_surface`, `expedition_business`: 저장 후 제작/장착 결과, 광물 등급·채광 간격, 굴착·공격 장비 판정.
- `expedition_feedback`: 장비 종류에 따른 모델 교체, 팬·피스톤/칼라 모션, 반동·광원·채광/펄스 효과. 교체 직후 잔여 흡입 입자가 트리에서 분리된 구 모델을 읽던 오류도 수정했다.
- [`build_handheld_equipment.py`](../../tools/build_handheld_equipment.py)로 펄스 카빈·지형 변환기의 Blender 원본과 GLB를 별도 제작했다. 채집기는 기존 `manual_tool.blend`/GLB를 재사용한다. 새 두 모델의 부품 구조·외형은 현재 플레이용 시제품이며 승인 기준작 품질의 최종 승인을 의미하지 않는다.
- Blender Cycles 원본 렌더와 Godot Metal Forward+ 공통 INK 스튜디오 렌더를 확인했다. 새 모델 2종을 `render_assets.json`에 등록하고 실제 렌더 PNG를 게임 카드에 연결했다. 등급별로 별도 형상을 제작한 것은 아니다.
- 음원은 기존 ElevenLabs 생성본을 재사용한다. 채광은 타격/획득, 공격과 굴착은 펄스, 제작은 제작 완료, 장착은 체결, 거절은 배치 실패음을 사용한다. 새 음원 생성 없음. 원본과 프롬프트는 `audio/manifests/elevenlabs.json`에 유지한다.

[Blender 카빈](media/equipment/pulse_carbine-blender.png) · [Blender 지형 변환기](media/equipment/terrain_shaper-blender.png) · [INK 카빈](../../우주-비즈니스/assets/ui/previews/pulse_carbine.png) · [INK 지형 변환기](../../우주-비즈니스/assets/ui/previews/terrain_shaper.png)

## 확인 범위

`tests/test_equipment_play.gd`는 임시 프로필·세계로 현재 원정 장면을 실행한다. 한 번의 짧은 흐름에서 착륙, 기초 제작/장착, 배낭 재료 차감, 모델 전환, 실제 지형 변경, ElevenLabs 재생, 결정 등급 제한/획득, 작은 화면과 메뉴 차단, 저장 읽기·호스트 재시작을 확인한다. 상위 제작 재료와 광맥 접근 위치는 제한된 검사 상태를 사용한다. 처음부터 모든 재료를 수동 파밍한 밸런스 검증은 아니다.

초기 검사에서 발견한 장비 교체 입자 오류는 수정했다. 채광 검사의 첫 위치가 유효 지면이 아니었던 문제와 저장 검사에서 JSON 실수/정수를 직렬화 문자열로 비교하던 문제를 각각 유효 지면·의미 있는 필드 비교로 수정했다. 실제 저장 장비 손실은 없었다.

최종 Godot 4.7.2 / Metal Forward+ / Apple M2 실행에서 **17개 확인, 실패 0, 오류 로그 없음**을 확인했다. 고정 시드 112052220의 유효 결정 광맥으로 재현한다. [검증 메타데이터](media/equipment/verification.json). 전체 회귀·다중 클라이언트·장시간 검사는 실행하지 않는다. 기존 검사 파일과 도구는 보존한다. 기존 ‘착륙 즉시 기본 만능 도구로 굴착’ 전제를 가진 테스트는 새 제작·장착 규칙에 맞춘 후속 갱신이 필요하며 이번 전체 통과로 주장하지 않는다.

동물 타격 판정·공유 체력/무력화 코드는 연결했지만 실제 동물 명중과 다중 참가자 동시 교전은 별도 미검증이다. 이번 실제 창 검사는 공격무기 발사까지다. 생물 반격·전리품, 다른 승무원이 든 장비의 3인칭 부착 표현, 신규 전투 음원·등급별 별도 모델, 제작 장비의 다른 세계 반출은 남아 있다.

[아이템창 960×640](media/equipment/inventory-960.png) · [소유 장비](media/equipment/owned-960.png) · [펄스 카빈 장착/발사](media/equipment/pulse-equipped.png) · [지형 변환](media/equipment/terrain-action.png)

재실행 예시(빈 임시 폴더 사용):

```bash
./tools/godot.sh --script res://tests/test_equipment_play.gd -- --crew-ui-test --crew-folder=/tmp/space-equipment-review
```

`--crew-folder` 폴더는 실행 전에 생성한다. 일반 사용자 프로필·세계와 섞지 않는다.

## 후속 UI/UX 개편

장비의 제작/저장 규칙은 유지하고, 목록/슬롯 드롭다운 화면은 [FIELD v1 적용](23-uiux-implementation.md)의 실제 3D·격자·클릭/드래그 장착 화면으로 교체했다. 위 스크린샷은 최초 구현 이력이다.

## 2026-09-07 — 흡입 동작과 스캔 후속 개선

위 최초 구현의 채집 타격/반동은 연속 흡입·팬 음향으로 대체했다. 표면 스캔과 카빈 반동도 개선했다. [변경·실제 확인·남은 범위](40-field-tool-feedback.md).
