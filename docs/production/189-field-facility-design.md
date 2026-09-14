# 현장 건물 9종 형태 고도화

2026-09-14 사용자 추가 요청: 건설하는 건물의 디자인·형태를 개선하고 커밋한다. 기존 INK v1과 산업 재질 규격을 유지하면서 주요 건설 설비 9종의 Blender 원본·게임 GLB·B 카드 이미지를 교체했다.

## 실제 변경

| 설비 | 형태 개선 |
| --- | --- |
| 태양광 발전기 | 두 집광 날개, 경사 힌지·지지대, 전면 전력 변환부 |
| 로봇 충전기 | 입출고 경사판, 양쪽 도킹 어깨, 후면 변압기와 냉각 루버 |
| 현장 제작소 | 개방형 상부 프레임, 경사 버팀대, 분리된 정비문과 내부 작업 암 |
| 현장 창고 | 모서리를 깎은 적재 상자, 분리된 화물문·잠금장치·적층 모서리·인양 손잡이 |
| 대기 처리기 | 분리탑 주위 곡선 흡입관, 교체형 처리 카세트, 상부 차폐판 |
| 온도 조절기 | 경사 열교환 지지대, 굵은 냉각 핀과 상하 배관 |
| 물 추출기 | 받침 위 수평 압력 탱크, 검사창·밸브·전면 필터 3개 |
| 생태 배양기 | 배양실 외부 케이지·상부 링, 영양액 보호함·환기 핀 |
| 소형 원자로 | 길쭉한 플라스마 용기, 상하 유도 링·4방향 버팀대·냉각 펌프 |

공통으로 3.6m 기반의 모서리를 깎은 기초판, 독립 지면 받침과 고정 나사, 측면 스키드·포크 삽입부·주황색 전면 문턱을 사용한다. 기존 전면(-Y), 배치 간격·충돌 판정·비용·연구·저장 ID를 유지한다. 환경 설비 4종의 `Anim_*` 위치·축·부모 변환을 이전 출력과 대조해 유지했다.

![고도화 후 Godot Forward+](media/facility-design/facilities-after.png)

[같은 조건의 변경 전](media/facility-design/facilities-before.png) · [낮 혼합](media/facility-design/mixed-day.png) · [그늘](media/facility-design/mixed-shade.png) · [역광](media/facility-design/mixed-backlight.png)

## 제작·검수

- `tools/build_field_facilities.py`: 공통 `ink_blender.py`·산업 재질을 재사용한다. 편집 가능한 개별 부품 상태의 `.blend`를 먼저 저장한 후, 가동 부모·재질별 정적 표면을 합쳐 GLB를 출력한다.
- Blender 5.2.1 LTS/Cycles에서 9종을 개별 렌더했다. 해당 폴더의 `*-blender.png`가 원본 결과다. Godot 4.7.2 Forward+/Metal에서 9종 개별·혼합 3조명과 480×400 투명 카드 이미지를 렌더했다.
- 기존 산업·후속·창고 제작 진입점도 새 생성기로 연결해 재생성 시 구형으로 돌아가지 않게 했다. 가동 부품 후처리는 새 원본의 축을 보존한다.
- 격리된 `/tmp/facility-design-play` 원정에서 실제 B 선택→고스트→휠 90도 회전→설치→원래 비용 한 번 차감→저장 재읽기, 환경 설비 4종의 기존 가동 모션까지 **23항목 통과**했다. 실제 사용자의 저장은 수정하지 않았다.
- 환경 4종은 실제 원정의 모델 표시 계층에 작업 상태를 주입해 모션을 확인했다. 네 설비를 모두 실제 비용으로 건설하거나 환경 생산 주기를 완주했다는 의미는 아니다. 설치/저장 검사는 태양광 1종이다.
- 새 효과음이나 동작 규칙은 추가하지 않았다. 기존 건설 효과·소리 호출 경로를 유지하며 이번에 별도의 청음 판정은 하지 않았다.

[960px 건설 카드](media/facility-design/build-cards-960.png) · [배치 고스트](media/facility-design/solar-ghost.png) · [실제 설치](media/facility-design/solar-installed.png) · [환경 설비 현장](media/facility-design/water-field.png)

카드 배경 수정 후 9개 PNG의 투명 알파를 확인하고, 960px B 화면을 다시 확인했다. 첫 물 추출기 촬영은 인접 설비에 가려져 카메라를 바꿔 4종을 다시 촬영했다. 이 좁은 재촬영의 모델/모션 검사 13항목도 통과했다. [설치 검사](media/facility-design/play-check.txt) · [재촬영 검사](media/facility-design/final-review.txt).

## 행동 범위와 비용

B 열기→기존 미리보기 로딩, 카드 선택→해당 설비 고스트 1개, 설치 요청→기존 호스트 검증·비용/저장·발행→해당 설치 모델 생성 경로를 유지했다. 도메인 코드·네트워크 처리·지형 캐시·화면 갱신 루프는 변경하지 않았다. 자산 재생성은 요청된 ID만 갱신한다. 실행 검사용 표시 상태의 복사/주입은 테스트 파일에만 있다.

형태 보강으로 삼각형 수는 증가했다. 정적 표면 병합을 유지하지만 성능 향상으로 기록하지 않는다. 대규모 기지 프레임 측정·전 기종 LOD·6인/Windows 실기는 이번 검수 범위가 아니다.

| 자산 | 출력 삼각형 | 출력 메시 |
| --- | ---: | ---: |
| solar | 32,736 | 14 |
| charger | 27,156 | 7 |
| factory | 35,744 | 6 |
| storage | 26,752 | 6 |
| atmosphere | 39,528 | 8 |
| thermal | 38,424 | 8 |
| water | 49,716 | 9 |
| biolab | 59,320 | 12 |
| reactor | 38,036 | 7 |

기계별 상세 수치·가동 변환은 [geometry.json](media/facility-design/geometry.json)을 따른다. 벽·차양·후속 전문 설비 등 이번 9개 ID 밖의 건설물은 형태 교체에 포함하지 않았다.

## 재생성·좁은 확인

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_field_facilities.py
tools/godot.sh --headless --editor --import --quit
tools/godot.sh --resolution 1440x1200 res://scenes/showcase/facility_design.tscn
```

카드만 다시 출력할 때는 마지막 명령 뒤에 `-- --icons-only`를 붙인다. PNG 출력 뒤 에디터 임포트를 수행한다. 실제 설치 검사는 착륙 상태 테스트 원정과 프로필을 격리 폴더에 준비한 뒤 아래 명령을 사용한다. 이 검사는 해당 **테스트 원정**에 태양광을 추가한다.

```sh
tools/godot.sh --script res://tests/check_facility_design_play.gd -- --crew-ui-test --crew-folder=/tmp/facility-design-play
```

`--cards-only`는 960px 카드 촬영만, `--field-only`는 기존 설치 기준의 환경 모델/모션 촬영만 실행한다.
