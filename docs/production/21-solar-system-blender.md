# 태양계 행성 Blender 제작과 게임 연결

2026-09-06 사용자 요청에 따라 이전 절차적 구체로 표시하던 태양계 8행성을 Blender 원본·게임용 모델로 교체했다. 광물 종류·재화 분포·행성 환경 확장은 사용자가 **의견만 요청한 범위**이므로 이번 제작에 포함하지 않았다.

## 제작물

[8행성 모음](media/solar-system/solar-system-board.png) · [Blender 원본 매니페스트](../../art/blender/solar-system/manifest.json) · [게임 모델 매니페스트](../../우주-비즈니스/assets/models/solar-system/manifest.json)

| 행성 | 표현 |
| --- | --- |
| 수성 | 모델 표면의 충돌구·테두리 융기·회색 정점 채색 |
| 금성 | 불투명한 크림색·황금색 대기 무늬 |
| 지구 | 해안선 기반 대륙·바다·극지, 별도 구름 메시 |
| 화성 | 붉은 표면·협곡·충돌구·극관 |
| 목성 | 띠 구름·타원형 폭풍·편평한 구체 |
| 토성 | 편평한 본체·분리된 여러 고리와 간극 |
| 천왕성 | 청록 대기·크게 기울어진 축·가는 고리 |
| 해왕성 | 청색 대기·얕은 띠·폭풍 표현 |

Blender 5.2.1 LTS에서 원본 `.blend` 8개와 근거리/원거리 `.glb` 16개를 제작했다. 모든 원본은 재질·메시·조명·카메라를 포함한다. 근거리 전체 779,060삼각형, 원거리 전체 91,528삼각형이다. 지구는 해안선 표현을 위해 높은 분할을 사용한다. 원정 화면은 거리 기준으로 두 단계 모델을 전환한다.

제작 스크립트는 [build_solar_system.py](../../tools/build_solar_system.py)다. 개별 수정은 `-- --planet=earth`처럼 선택할 수 있다. 주요 편집 전에 원본을 저장했고 지구 수정 때 Blender를 다시 실행하여 원본·내보내기·렌더를 갱신했다.

## 자료와 해석

지구의 대륙 윤곽은 [Natural Earth 1:110m land](https://www.naturalearthdata.com/downloads/110m-physical-vectors/110m-land/)를 정점 채색으로 변환했다. 해당 데이터는 [public domain](https://www.naturalearthdata.com/about/terms-of-use/)이다. 취득한 원본 ZIP·URL·SHA-256은 [자료 기록](../../art/reference/solar-system/sources.json)에 보존한다. 정치 경계·국가 표기는 사용하지 않는다.

행성의 식별 특징은 [NASA 태양계 행성 안내](https://science.nasa.gov/solar-system/planets/)를 참고했다. NASA 사진을 텍스처로 복사하지 않았다. 다른 행성의 표면 무늬·충돌구 위치·폭풍·구름·색은 직접 제작한 카툰 표현이며 관측 지도나 정확한 천체력 재현이 아니다. 천체의 게임 반지름·거리·자전은 축약된 표현이다.

## 실행 경로

`FrontierSpaceFlight._load_system()`에서 `solar_reference`인 8행성은 [FrontierSolarPlanet](../../우주-비즈니스/scripts/world/solar_planet.gd)을 사용한다. 원정의 `FrontierCrewFlightView`도 같은 경로를 사용한다. 가상 시드 행성의 기존 생성 규칙은 유지한다.

- Blender의 정점 색은 공통 `FrontierInkStyle`의 `_vertex_paint` 재질 이름으로 연결한다. GLB에는 `COLOR_0`가 있지만 Godot 가져오기가 재질의 색 사용 플래그를 켜지 않는 문제를 해결했다. 독립 도감에서도 같은 변환을 사용한다.
- 공통 INK 3단 명암·윤곽선을 사용한다. 태양계 자산은 `highlight_strength`로 과도한 구체 반사만 줄이며 기존 자산의 기본값은 1로 유지한다.
- 구름과 본체는 호스트의 궤도 시간으로 자전한다. 대기층은 본체 메시를 재사용하여 편평도·축 기울기가 달라도 극지 위로 떠 있지 않는다.
- 토성·천왕성의 항해 접근 반경에 고리 외곽을 포함한다. 고리가 착륙 가능 지표가 되는 것은 아니다.
- 원본/모델은 공통 `render_assets.json`에도 등록했다. 새 광물·음원·지표 채집 규칙은 추가하지 않았다.

## 실제 확인 범위

Blender Cycles에서 8개 원본을 렌더하고 Godot 4.7.2 Metal Forward+ / Apple M2에서 같은 8개 자산의 정점색·공통 셰이더·자전과 실제 원정 항해 뷰를 확인했다. [검증 기록](media/solar-system/godot/verification.json)의 27개 확인 항목은 실패 0개, 마지막 렌더 실행의 엔진 오류 0개다. 공통 도감 변환에서도 지구의 정점색 사용을 별도로 확인했다.

[지구 실제 항해](media/solar-system/godot/game-earth.png) · [토성 실제 항해](media/solar-system/godot/game-saturn.png) · [Blender 지구](media/solar-system/blender/earth.png) · [Blender 토성](media/solar-system/blender/saturn.png)

원정 항해 뷰를 직접 생성한 짧은 렌더 확인이다. 전체 회귀·다중 클라이언트·장시간 성능 검사는 실행하지 않았다. 지구 도시·우주항, 지표의 실제 대륙 연결, 행성 전역의 지하·광물 생성까지 구현했다는 의미가 아니다. 태양 자체는 이번 **행성 8개** 제작 범위에 포함하지 않는다. 최종 미적 승인은 사용자 검토와 구분한다.
