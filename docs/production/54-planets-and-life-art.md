# 행성·생물 선별 개선과 내부 선 조정

2026-09-08 사용자 요청: 승인된 모델 품질을 행성과 생물 전체에 적용하고, 내부·작은 요소·원거리의 검은 선을 줄인다. 이어서 **판단상 바꿀 필요가 없는 생물은 유지해도 된다**고 확정했다. 전수 검토와 전수 재제작을 구분한다.

## 범위와 선별 기준

실제 목록은 약 300종이 아니라 **600개 기본형·30개 구조군**이다. 동물 400개(이형 100개 포함), 식물 125개, 미생물 군락 75개이며 기존 외형 프로필 12,000개를 갖는다. [원본 600개와 선 설정](media/ink-life/baseline.json), [기존 30개 구조군 비교판](media/ink-life/before-boards/), [개별 수정/유지 목록](media/ink-life/selection.json)을 보존한다.

| 판단 | 구조군 | 기본형 수 | 이유 |
| --- | --- | ---: | --- |
| 개선 | 뿔초식류·추적포식류 | 50 | 어깨/무릎 연결과 몸통 곡면, 코·귀의 구조 보완 |
| 개선 | 막날개류·유영어류·부유가오리류 | 75 | 전역 한 축으로 펼친 얇은 조각을 중심선에 수직인 두께·굽힘이 있는 날개/지느러미로 교체 |
| 개선 | 집수식생·수관식생·수생엽상체 | 75 | 잎의 면적·굴곡과 줄기 접합부 보완, 봉처럼 보이는 잎 줄이기 |
| 유지 | 암갑류·도약조류·굴착수류·갑각류·낫날절지류·환절사행류·여과연체류 | 175 | 갑각·실루엣·사지·감각기관이 이미 읽히며 일괄 형태 변경의 이점이 작음 |
| 유지 | 반사군락·균사체·기질처리막·열수군락·광합성군락 | 125 | 결정·갓·관·군락의 기존 구조와 역할 구분 유지 |
| 유지 | 이형 10개 구조군 | 100 | 구강·골격·비대칭 구조를 보존, 새 관절 장식만으로 개선 처리하지 않음 |

제작은 `tools/build_ink_bestiary.py`가 위 선택 목록을 기본값으로 사용한다. 원본 생성기의 개별 형태·눈 설계·감각 방식·팔레트를 재사용하며 Blender 편집 부품을 보존하고 움직이는 부모별 정적 표면만 병합한다. 선택에서 제외한 중간 제작 결과는 원본으로 되돌렸다. 모델 ID·환경·공격 유형·20개 외형 프로필과 기존 모션 피벗 이름을 보존한다. 600개는 제작 라이브러리의 기본형 수이며, 현재 게임의 환경별 출현 허용 풀을 600개로 확대하지 않는다.

## 행성 및 지표

`tools/build_ink_planets.py`로 태양계 참조 8개와 생성 행성 15계열을 제작했다. 태양계는 해안/대륙붕, 극지, 충돌구, 협곡, 구름과 거대행성 띠를 보완한다. 생성 행성은 고도·충돌구·지질 구조의 정점 마스크와 근거리/원거리 메시를 출력한다. 총 23개 Blender 원본, 46개 GLB다.

궤도 화면의 실제 로더에서 생성 행성의 원거리 메시를 사용하며 대기 셸도 같이 전환한다. 반지름 대비 거리 12배에서 원거리, 10배 안에서 근거리로 복귀하여 경계에서 반복 교체되는 현상을 줄인다. 태양계의 기존 근/원거리 모델 연결도 유지한다.

9개 착륙 지표는 기존 형태와 충돌을 유지하면서 건습 토양·설원/빙원·퇴적색·염각·화산재 색면을 재질에 연결한다. 실제 관측 자료를 새로 추가하거나 모든 과학적 행성 유형, 지질, 계절과 상변화를 구현한 것은 아니다. 별도 [행성 적용 범위 감사](53-planet-coverage-audit.md)와 [복합 표면 설계](../technical/09-planet-surface-materials-and-biomes.md)의 구현 공백을 유지한다.

![행성 게임 렌더](media/ink-life/planets-after.jpg)
![실제 9개 지표](media/ink-life/surfaces-after.jpg)

## 윤곽선

값은 [공식 INK v1 기준](06-rendering-quality-standard.md)과 `render_style.json`을 따른다. 외곽 3px, 식생 외곽 2.5px를 유지하면서 내부를 0.8px/0.55px로 조정했다. 내부는 15~55m, 외곽 대비는 28~110m에서 감쇠하며 작은 부속물의 검은 면적을 줄인다. 3단 명암은 유지한다.

[혼합 장면 전](media/ink-life/lines-before/mixed-day.png) · [후](media/ink-life/lines-after/mixed-day.png) · [약광](media/ink-life/lines-after/mixed-shade.png) · [역광](media/ink-life/lines-after/mixed-backlight.png) · [기준작 네 종](media/ink-life/references-after.png)

## 확인 현황

Blender 5.2.1 LTS의 실제 Cycles 렌더와 Godot 4.7.2 / Metal Forward+ / Apple M2를 사용했다. 행성 23종은 실제 로더·근/원거리 및 복귀 확인 81개, 지표 9계열은 실제 스트리밍과 착륙 높이 확인 37개를 통과했다. 행성 촬영용 항해 데이터의 누락된 `speed`를 보완한 뒤 해당 렌더를 다시 실행했고 오류가 없었다.

**생물 600개 검토, 200개 재제작, 400개 원본 유지, 600개 기본형 PNG와 게임 미리보기 갱신을 완료했다.** 600개 모두 근/원거리와 5개 상태의 피벗 동기화를 확인했고, 공격이 있는 320개는 공격 준비·활성·회복 및 대기 복귀를 확인했다. 30개 구조군의 대표 약광/역광·상태 촬영을 보존한다. 전체 렌더 및 자산 대조 실패는 0건이다.

[전후 대표 비교](media/ink-life/life-comparison.jpg) · [전체 구조군](media/bestiary/overview.jpg) · [수정한 8개 구조군의 전수 비교판](media/ink-life/review-boards/) · [Blender·약광·역광](media/ink-life/source-lighting-review.jpg) · [대표 동작](media/ink-life/motion-review.jpg) · [자산 대조](media/ink-life/asset-verification.json) · [최종 확인 수량](media/ink-life/verification.json).

수정한 200개 모델의 근거리 삼각형 합계는 3,016,492→6,605,138개, 새 원거리 합계는 1,844,898개다. 전체 라이브러리 합계이며 동시에 모두 렌더링한다는 뜻은 아니다. 곡면 보완으로 기하 비용이 늘었으며 이번 기록은 FPS 개선 실측이 아니다.

 기존 외형 프로필 12,000개의 데이터는 유지하며 이 프로필의 모든 색·크기 조합을 다시 촬영했다는 뜻은 아니다. 전역 게임 규칙·전체 회귀·장시간 멀티 검증은 실행하지 않는다.

## 재제작과 필요한 캡처만 재생성

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ink_bestiary.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ink_planets.py
python3 tools/bestiary/audit_ink_life.py --finalize
./tools/godot.sh --headless --editor --import
./tools/godot.sh --script res://tests/render_ink_life.gd
```

생물 제작은 완료 기록이 있는 기본형을 건너뛰며 ID/구조군을 `--` 뒤에 지정할 수 있다. 렌더는 모델·스타일 해시가 같은 완료 기록을 건너뛴다. 기존 행성 제작 진입점도 개정 자산을 구형 모델로 덮어쓰지 않도록 최신 제작기로 연결했다. 생물 LOD·개별 약광/역광 캡처는 `.gitignore` 대상이며 대표 비교판과 원본 자산은 보존한다. 이 명령 묶음 전체를 매 변경마다 다시 실행하는 규칙은 아니다.
