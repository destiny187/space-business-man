# A01~A06 요약과 통합 플레이 확인

2026-09-08 사용자 요청에 따라 A06 커밋 `5023d81a` 이후 실제 Godot 4.7.2 / Metal Forward+ 창에서 관련 플레이를 확인했다. [개발 계획](../planning/12-augmentation-and-research-commits.md)의 A07 이후를 완료로 확대하지 않는다.

| 단계 | 구현된 내용 |
| --- | --- |
| A01 | 세계 안 개인 캐릭터의 기동·전투·생명 증강과 저장. 이동속도·펄스 피해·최대 체력에 적용하고 기존 물류 성장을 이행한다. |
| A02 | 본인 배낭 보석 차감과 증강 단계 증가를 같은 호스트 저장 거래로 확정한다. 거리·소유·중복·저장 실패를 처리한다. |
| A03 | Blender 증강 장치와 표본 연구대. 기본선 선내와 착륙선 측면에서 F로 접근한다. |
| A04 | 자기 캐릭터 부위 선택·보석 슬롯·전후 능력·장치 모션/음향과 I 신체 열람을 연결한다. |
| A05 | 원정대 공유 연구 원장, 실제 발견 증거, 본인 표본 기여, 이전 세계 사용권 이행을 구현한다. |
| A06 | 표본 실물·분석·미조립 헤드·제작소 Mk.2 시험기 조립·장비 장착/화물 운송·J 공동 기록을 연결한다. |

현재 **개인 증강 루프와 공동 연구의 시제품 단계**까지 가능하다. 실제 지하 시험 판정, 정식 Mk.3 개방, 다이아몬드 정밀 헤드 개조는 A07이다.

## 이번 실제 확인

| 경로 | 결과와 범위 |
| --- | --- |
| 증강 | 21개 확인 통과. 세 보석으로 실제 구매, 잘못된 보석·호스트 거절·중복 클릭, 실제 지상 속도, 장착 무기 피해, 120 체력 HUD, 장비 교체·세계 재개 확인. |
| 연구·시험기 | 18개 확인 통과. 연구대 F·표본 드롭·회전판·분석 성공/거절 음향, J, 실제 착륙, 전력이 공급된 제작소, 조립·손 장비 모델·선박 화물 보관/회수·디스크 재로드 확인. |
| 실제 보석→연구 | 11개 확인 통과. Mk.2 개조 거래 후 시드 동굴의 사파이어 `cave:gem:0`을 실제 카메라 물리 조준과 장비 사용으로 채집. 호스트가 채집 재고와 `extraction` 증거를 생성하고, 착륙선 측면 연구대 F에서 회수 보석 3개로 분석 완료. 해당 광맥 ID·분석 상태의 저장 확인. |
| 안내 겹침 수정 | 4개 확인 통과. I 신체 화면 위에 항해/채집 가이드가 겹치는 문제를 재현해 수정했다. 아이템창 방문 기록은 유지하고, 창을 닫으면 현재 장비에 맞는 안내를 다시 표시한다. |

총 54개 관련 확인에서 최종 실패는 없었다. 이것은 새 게임 자연 진행 54단계를 완주했다는 뜻이 아니다. 증강용 보석·시험기 부품·발전 시설 배치는 준비한 fixture다. 추가 보석 확인에서는 Mk.2 부품과 현장 이동 위치를 준비했지만, **보석 재고·발견 증거·분석 성공은 주입하지 않았다.** 지하를 입구부터 도보로 탐색하거나 건설 재료를 모두 직접 파밍한 장기 플레이는 아니다. 실접속 멀티·6인 동시 조작·FINCH 독립 원정·다른 세계 계승도 확인하지 않았다.

UI 음향은 기존 ElevenLabs 스트림을 실제 재생했다. 증강 UI 버스 녹음 4.34초의 정규화 피크 0.200, RMS 0.030으로 출력과 클리핑 부재를 확인했다. 모든 환경음/대기 루프의 청음 승인을 뜻하지 않는다.

## 수정과 저장 격리

`first_departure.gd`에서 아이템창 예외 때문에 가이드가 메뉴 위에 남던 문제를 수정했다. 아이템창의 지상 방문 기록을 먼저 갱신한 뒤 일반 메뉴와 같이 안내를 숨긴다. 지도를 닫도록 돕는 기존 항해 지도 안내는 유지한다.

`check_augmentation_ui.gd`에 필수 `--crew-ui-test` 가드를 추가했다. 증강·연구 실제 창 검사 모두 시작 후 실제 세계 경로·테스트 모드·예상 캐릭터를 확인한 뒤 fixture를 적용한다. 새 채집 연결·가이드 검사는 지정한 `/tmp` 경로와 격리 플래그 없이는 시작하지 않는다.

이번 모든 실행은 격리 경로를 사용했다. 기존 선택 설정·프로필/세계 JSON·백업 **242개 파일의 실행 전후 SHA-256이 동일**했다. [비교 결과](media/augmentation-research-playcheck/save-audit.txt).

[증강 로그](media/augmentation-research-playcheck/augmentation.txt) · [연구 로그](media/augmentation-research-playcheck/research.txt) · [실제 채집 연결](media/augmentation-research-playcheck/gem-research.txt) · [가이드 수정](media/augmentation-research-playcheck/guide-fix.txt)

[가이드 수정 전](media/augmentation-research-playcheck/body-before-guide-fix.png) · [수정 후 960px 신체 화면](media/augmentation-research-playcheck/body-after-guide-fix.png) · [실제 보석 채집](media/augmentation-research-playcheck/gem-mined.png) · [회수 표본 분석](media/augmentation-research-playcheck/mined-sample-analysis.png) · [시험기 제작](media/augmentation-research-playcheck/factory-complete-960.png)

```sh
./tools/godot.sh --script res://tests/check_augmentation_ui.gd -- --crew-ui-test --crew-folder=/tmp/augmentation-a04
./tools/godot.sh --script res://tests/check_research_visuals.gd -- --crew-ui-test --crew-folder=/tmp/research-a06-ui
# 연구 검사가 만든 world.json/profile.json을 /tmp/a01-a06-gem에 복사한 뒤 실행
./tools/godot.sh --script res://tests/check_gem_research_play.gd -- --crew-ui-test --crew-folder=/tmp/a01-a06-gem
./tools/godot.sh --script res://tests/check_inventory_guide.gd -- --crew-ui-test --crew-folder=/tmp/augmentation-a04
```
