# 굵은 검은선 카툰 — 네 가지 아트 예제

## 요청과 현재 상태

2026-09-06 사용자가 참고 화면을 제공하고 기존의 모델 품질을 유지하면서 굵은 검은선을 중심으로 하는 카툰 렌더링을 제안했다. 로봇·자원·풀·건물을 각각 하나씩 실제 렌더로 확인하는 요청이다. 참고 화면의 굵은 실루엣, 내부 윤곽, 단계형 명암을 표현 기준으로 삼았다. 이후 사용자가 이 방향을 모든 개발 요소에 적용하도록 승인했다. 현재 기준은 [공식 렌더링 품질 기준 INK v1](06-rendering-quality-standard.md)이며, 이 문서는 네 기준작의 제작 이력이다.

## 네 가지 예제

| 종류 | 내용 | 원본 |
| --- | --- | --- |
| 로봇 | 고품질 연구 장면의 M-07 형상을 유지하고 새 잉크·명암 셰이더 적용 | `art/blender/showcase/locus_m07.blend` |
| 자원 | 사암이 아닌 어두운 모암에 청록 결정과 노출된 구리맥을 결합한 광물 군집 | `art/blender/ink-study/mineral_deposit.blend` |
| 풀 | 두께와 곡률이 있는 넓은 잎 15개, 가는 중앙 잎맥을 가진 풀 한 포기 | `art/blender/ink-study/frontier_grass.blend` |
| 건물 | 출입문·창·패널·통풍구·배관·옥상 압축기와 배기구를 갖춘 정제소 | `art/blender/ink-study/ore_refinery.blend` |

새 모델 세 개는 Blender에서 원본을 저장하고 GLB로 내보냈다. [생성 도구](../../tools/build_ink_samples.py)와 [매니페스트](../../art/blender/ink-study/manifest.json)에 재제작 경로를 보관했다. 로봇은 앞선 원본을 재사용하므로 원본을 네 개 새로 만들었다고 해석하지 않는다.

## 렌더링 방식

- 실루엣과 가려짐 경계는 굵은 검은 선, 부품·면의 경계는 더 가는 선으로 분리한다.
- 화면 깊이와 법선의 불연속을 검출하므로 모델을 낮은 폴리곤으로 바꿀 필요가 없다.
- 직접광은 3단 명암으로 정리하고 도장·금속·렌즈의 거칠기에 따라 작은 하이라이트를 남긴다.
- 풀은 실루엣 선 폭을 조금 줄이고 내부 선을 가늘게 해 잎 사이가 검게 뭉치는 것을 줄인다.
- 작은 양각 문자의 깊이 변화는 내부 윤곽에서 억제하여 글자가 검은 점으로 뭉치는 현상을 줄였다.
- 4× MSAA와 1.5배 3D 렌더 스케일을 사용한다. 모델·그림자·윤곽은 엔진 안에서 렌더되며 UI를 포함한 최종 출력은 장당 1440×1200이다.

깊이 복원과 화면 법선 읽기의 API 기준은 [Godot 고급 후처리](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html), [화면 읽기 셰이더](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)다. 이 구현은 현재 프로젝트의 Forward+를 대상으로 한다.

## 실행·재제작

```bash
./tools/show_ink_samples.sh
./tools/show_ink_samples.sh -- --capture
./tools/godot.sh --headless --script res://tests/check_ink_samples.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ink_samples.py
./tools/godot.sh --headless --editor --import
```

`1`~`4`로 종류 선택, 왼쪽 드래그로 회전, 휠로 확대·축소, Space로 자동 회전, O로 윤곽선 켜기·끄기, Esc로 종료한다. 이 뷰어는 캠페인·세이브와 독립된 장면이다. 후속 INK v1 적용으로 실제 게임과 공통 셰이더를 사용한다.

촬영 명령은 각 종류를 차례로 촬영하고 종료한다. 개별 PNG 네 장과 이를 축소 없이 조합한 2880×2400 모음 이미지는 `test-results/ink-study/`에 기록한다. 검토용 사본은 아래에 보관한다.

![네 가지 굵은 검은선 카툰 예제](media/ink-study-board.png)

[로봇](media/ink-study-robot.png) · [자원](media/ink-study-resource.png) · [풀](media/ink-study-grass.png) · [건물](media/ink-study-building.png)

## 적용 범위와 검증

이 스튜디오는 승인된 네 자산의 스타일과 가독성을 확인하는 기준 장면이다. 별도 성능 목표나 대규모 게임 화면의 가독성까지 확정한 결과는 아니다. 특히 먼 거리의 많은 풀·로봇은 선의 밀도를 줄이는 거리별 규칙을 추가 검토해야 한다.

Godot 4.7.2 / Metal Forward+에서 네 가지 실제 렌더와 정상 종료를 확인했다. 최종 촬영의 엔진 오류는 0건이다. 별도 검사로 네 모델의 로딩·경계·카메라, 화면당 한 자산 유지, 제목 대응, 윤곽선 전환, 자동 회전을 확인했다. Blender 원본 세 개와 GLB의 실제 삼각형 수도 매니페스트와 대조했다. [촬영 메타데이터](media/ink-study-renders.json)를 함께 보관한다.
