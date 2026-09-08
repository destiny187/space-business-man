# A06 — 표본 분석과 시제품 실물

2026-09-08 [A01~A09 계획](../planning/12-augmentation-and-research-commits.md)의 A06을 구현했다. **원정선 연구대 F → 표본 배치·분석 → 현장 제작소 Mk.2의 시험기 조립 → I 장착·화물 보관**까지 연결한다. 실제 지하 현장 시험 판정, Mk.3 설계 개방과 다이아몬드 개조는 A07이다.

## 실제 조작과 화면

- 연구대는 발견한 사파이어·루비·에메랄드 실물과 표본→분석→시험기→정식 설계 연결선을 표시한다. 미발견 표본과 미완료 노드는 어둡게 구분한다. 보석 클릭 또는 표본 슬롯 드롭으로 준비하고, 자기 배낭에서 낼 수량을 선택해 계측한다. 준비만으로 재료를 소비하지 않는다.
- 기존 Blender 연구대의 회전판·광학 암, 실제 보석 모델과 계측 파형을 함께 움직인다. 분석 완료 후에는 분리된 헤드·덮개가 있는 시험기 미리보기를 보여준다. 제작 성공 응답 뒤에 부품이 결합한다. 미래 Mk.3는 기존 채집 모델의 어두운 목표 아이콘이며 신규 정식 Mk.3 모델을 제작했다는 뜻이 아니다.
- J의 첫 **탐사 연구** 탭은 공동 현황 열람 전용이다. 선내·지상에서 열리며 선내 스냅샷 수신으로 닫히지 않는다. 기존 생태·공학 메뉴는 보존했고, 지상 전용 탭은 선내에서 감춘다. FINCH 연구대 원격 조작은 추가하지 않는다.
- 현장 제작소의 **시험기 조립** 탭은 사용 중인 제작소에 고정한다. 최초 조정값은 강화 프레임 1개·제어 회로 1개다. **자기 배낭의 부품**을 명시적으로 사용하며 공동 창고를 자동 차감하지 않는다. 재제작도 같은 비용을 지불한다.
- 결과는 일반 장비 ID를 가진 `miner_probe`다. I에서 번호 슬롯에 장착하고 기존 선박/현장 화물 경로로 보관·회수할 수 있다. 등급은 T2, 회수량 3·간격 0.5초로 데이터화해 T3 채집을 우회하지 않는다. 휴대 제작으로 연구 조건을 건너뛸 수 없다.

## 거래와 저장

`equipment_research_prototype`는 프로젝트·실제 제작소 ID·예상 연구 단계만 받는다. 호스트는 분석 완료, 지상 접근, 운영 중인 Mk.2 이상 제작소, 8m 거리, 전력, 기존 생산/로봇/공학/로버 작업, 개인 재료와 장비 공간을 확인한다. 부품 차감·장비 발급·연구 단계·영수증을 같은 복사본에 적용해 저장한 뒤 공개한다. 같은 요청 재전송은 기존 영수증을 돌려주며 저장 실패는 전부 원복한다.

원장 버전은 2다. A05의 유효한 버전 1은 발견·기여·분석·legacy 사용권을 보존하고 빈 `prototype` 필드만 추가한다. `prototyped` 단계와 최초 제작자·장비 ID·행성을 함께 기록한다. 이후 같은 장비를 화물로 옮기거나 다른 승무원이 재제작해도 최초 제작 기록을 덮지 않는다. 이 필드는 현재 장비 위치를 뜻하지 않는다. JSON 재로드의 정수/실수 숫자 표현을 같은 유효 버전으로 처리한다.

제작소 UI는 현장 시설 상태와 최신 개인 배낭 스냅샷을 결합해 가능 여부를 판단한다. 배낭 갱신이 현장 패킷보다 먼저 오면 이전 수량으로 조립 버튼을 막던 표시 문제를 수정했다.

UI는 요청 순번을 추적하고 해당 호스트 응답 뒤에만 성공 표시·결합·완료음을 실행한다. 응답 리비전의 스냅샷을 받기 전 재실행을 막는다. 숨긴 화면을 응답 때문에 다시 열지 않으며 처리 음향을 정지한다.

## 자산과 확인

- [Blender 원본 렌더](media/research-a06/miner-probe-blender.png): 공통 INK 재질·곡면·가동 그룹을 사용한 시험기. 원본은 `art/blender/equipment/miner_probe.blend`, 생성기는 `tools/build_research_probe.py`, 출력·편집 부품 수는 같은 폴더의 `research-probe-manifest.json`에 둔다.
- [표본 준비](media/research-a06/prepared.png), [분석 결과](media/research-a06/analyzed.png), [960px J 열람](media/research-a06/journal-960.png), [제작소 미조립 헤드](media/research-a06/factory-exploded-960.png), [시험기 조립 완료](media/research-a06/factory-success-960.png), [실제 장착](media/research-a06/probe-equipped.png).
- ElevenLabs 기존 `sfx_pickup_resource`, `sfx_robot_charge`, `sfx_factory_complete`, `sfx_build_invalid`를 준비·응답 대기·성공·거절에 재사용한다. 신규 음원은 생성하지 않았다. 실제 UI의 거절/성공 스트림 재생과 닫을 때 정지를 확인했다. 음향 매핑은 `audio/manifests/crew-stations-reuse.json`에 기록한다.
- Godot 4.7.2 / Metal Forward+ 실제 창에서 표본 드롭·회전판·계측·J·착륙·발전된 제작소·조립·손 장비·선박 화물·디스크 재로드 18개 확인을 통과했다. 작은 제작소 화면과 결합 모션은 레이아웃 변경 후 관련 4개 확인을 통과했다.
- 관련 시제품 거래 17개와 A05 저장 스키마 관련 기존 30개 검사를 통과했다. 전체 회귀·6인 인터넷·FINCH 독립 출동·장시간 운송·현장 시험은 이번에 검증하지 않았다. 발견과 발전 시설 배치는 격리 fixture이며 새 게임의 전체 자연 진행을 완주한 기록은 아니다.

검증 명령과 출력은 [거래](media/research-a06/prototype-rules.txt), [A05 호환](media/research-a06/ledger-rules.txt), [실제 창](media/research-a06/live.txt), [작은 화면·조립 모션](media/research-a06/layout.txt)에 보존한다.

검증 과정의 한계: 초기 실제 창 실행 1회에 `--crew-ui-test`가 빠져 기존 선택 저장을 열고 자동 저장했다. 테스트는 캐릭터 ID 불일치에서 중단되어 그 저장에 표본·부품·시험기를 넣지 않았다. 자동 저장은 연구 스키마 이행과 세션/공전 시간 갱신을 포함할 수 있으며 원본 그대로 보존했다고 주장하지 않는다. 이후 `/tmp/research-a06-ui`와 필수 격리 플래그 검사로 검증했다. 초기 임시 fixture의 필수 재고 키·지형 설정 누락도 수정한 뒤 위 최종 결과를 확인했다.

```sh
./tools/godot.sh --headless --script res://tests/check_expedition_research.gd
./tools/godot.sh --headless --script res://tests/check_research_prototype.gd
./tools/godot.sh --script res://tests/check_research_visuals.gd -- --crew-ui-test --crew-folder=/tmp/research-a06-ui
# 위 실제 창 검사가 만든 격리 저장에서 화면/조립 모션만 확인
./tools/godot.sh --script res://tests/check_research_visuals.gd -- --crew-ui-test --crew-folder=/tmp/research-a06-ui --layout-only
```
