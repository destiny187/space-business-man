# SP03 — Space Y 복원 화성

2026-09-10 사용자 요청으로 새 은하의 화성을 Space Y 복원 완료·관리 행성으로 연결했다. 지표 도시 방문은 이번 범위가 아니다.

## 구현

새 manifest의 `settings.corporate_space` v1에 운영사·복원 상태·궤도 접근 정책과 대기 표현을 고정한다. `solar:3`의 주소·종류·티어·기준 자료·공전/자전은 유지하고 별도 `management`에 게임 설정을 제공한다. 기존 manifest에 이 값이 없으면 원래 붉은 화성·환경·제한 문구를 유지한다. 저장을 열면서 새 설정을 삽입하지 않는다.

`tools/build_restored_mars.py`는 기존 직접 제작한 화성 협곡·고지대 위에 북부 수역·해안 녹화·구름층을 만든다. 지구 대륙을 복제하지 않았으며 수역·녹지는 미래 게임 표현이다. `.blend`와 근거리/원거리 GLB를 별도로 보관했다. 실제 우주 뷰와 항성지도 미리보기에 같은 모델을 연결했고, 공통 INK 셰이더의 푸른 대기·구름·절제된 밤면 불빛을 사용한다.

주시 스캔에 Space Y 심볼·복원 완료·관리 구역을 표시한다. 새 세계의 첫 출항 편지도 화성을 안내한다. 태양계 지표 착륙·채굴·건설 제한을 유지하며 회사의 선행 복원을 플레이어 점수나 수익으로 지급하지 않는다. 궤도 교역은 SP04 소관이다.

## 확인과 경계

Blender 5.2.1 Cycles 원본 렌더와 Godot 4.7.2 Forward+ / Metal 실제 항해 뷰를 확인했다. `check_restored_mars.gd`에서 신규/기존 세계·주소/공전 보존·저장 검증·착륙 제한·보상 없음·주시 스캔·LOD를 확인했다. 스캔 아이콘의 임시 Texture 참조가 해제되어 흰 사각형이 되던 문제를 고정 참조로 수정했다.

[신규 화성 스캔](media/corporate-space/mars-restored-scan.png) · [근거리](media/corporate-space/mars-restored-near.png) · [원거리](media/corporate-space/mars-restored-far.png) · [기존 세계](media/corporate-space/mars-legacy-near.png) · [Blender](media/corporate-space/mars_restored.png)

검수는 격리된 생성 세계와 현재 항해 장면을 사용했다. 실제 사용자 저장·전체 지상 흐름·다중 접속·Windows·장시간 성능은 다시 검사하지 않았다. 스캔의 기존 ElevenLabs 재생 연결을 유지했고 신규 음원을 만들지 않았다. 복원 기후 시뮬레이션·화성 지표 콘텐츠는 구현하지 않았다.
