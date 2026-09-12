# 지상 생물 보행·접지 고도화

2026-09-12 사용자 승인: 걷는 모습이 어색한 생물을 확인한 뒤 지상 이동 전반을 다듬는다. 현재 카탈로그의 **지상 동물 기본형 5,130종**에 이동 거리 기반 보행과 체형별 동작을 연결했다. 종 수·자연 원산지·출현 확률·공격 성향과 티어별 전투 수치는 유지한다. 생태 규칙의 소관은 [발견·연구·생태](../game/09-discovery-research-and-ecology.md), 전투는 [27번](../game/27-ground-and-flight-combat.md)을 따른다.

## 바뀐 동작

- 실제 이동 거리·몸집·다리 길이에 따라 보폭과 주기를 정한다. 느린 배회·추격·고티어 돌진에서 같은 속도로 발만 반복하던 문제를 줄였다. 공격 단계가 바뀌어도 보행 주기를 처음부터 다시 시작하지 않는다.
- 네발은 천천히 걸을 때의 네 박자와 달릴 때의 대각 지지를 섞는다. 두발 교대, 여러 다리의 교대/파동, 방사형 발의 순차 지지, 뒷다리 도약, 기어가기·몸통 굴곡을 구분한다. 종 ID 해시로 다리 순서를 정하지 않고 실제 발 위치를 사용한다.
- 디딘 발은 월드 위치를 유지하고 다음 발자리를 짧게 탐색한다. 기존 고관절·무릎·발목이 있는 모델은 두 구간 관절 계산으로 길이를 보존하고 발바닥을 지형에 맞춘다. 회전된 방사형 관절의 마커 축과 실제 스킨 뼈 축이 달라 발이 뒤틀리던 연결도 수정했다.
- 방향 전환을 제한 속도로 이어 주며 정지하면 들고 있던 발을 내려놓는다. 메뉴 정지 중 자세를 유지하고, 큰 위치 이동 뒤에는 발 접점을 다시 잡는다. 가까운 모델과 먼 모델은 같은 보행 주기와 접점을 사용한다.
- 일반 동물과 토착 생물 사건·새끼·거대 개체를 같은 구동기에 연결했다. 스캔·충돌·피해는 호스트의 실제 위치를 유지하고 모델 표시만 짧게 보간한다. 표시 위치의 지연 한도는 `0.18 × min(2, 크기 배율)m`이다.
- 기존 발 디딤 먼지는 실제 접촉 시점에 나온다. 다리 없는 생물은 몸통 이동 주기에 맞춰 지면 먼지를 낸다. 거대/동굴 사건의 기존 울음과 일반 생물의 경고·타격 음원 연결을 유지했다.

조정값은 `data/ground_locomotion.json`, 모델별 발 위치는 `data/bestiary/ground_locomotion.json`에 둔다. 후자는 `tools/bestiary/build_ground_locomotion.py`가 Blender에서 내보낸 GLB의 관절·스킨 가중치·발바닥 정점으로 생성한다. 별도 종이나 외형 변이를 추가한 데이터가 아니다.

| 이동 구분 | 기본형 수 |
| --- | ---: |
| 여러 다리 | 858 |
| 네발 | 790 |
| 두발 | 25 |
| 방사형/홀수 지지 | 2,351 |
| 도약형 | 21 |
| 몸통 굴곡 | 378 |
| 기어가기 | 707 |
| 합계 | 5,130 |

다리가 있는 모델은 4,045종, 다리 없는 지상 모델은 1,085종이다. 식물·미생물·수중·대기 부유·조류 비행을 지상 보행 개선 수에 포함하지 않는다.

## Blender 관절 수정 40종

`accordion_shell`, `knuckle_chain`, `petal_mantis`, `corkscrew_spine` 각 10종은 다리가 몸통 판과 한 덩어리로 묶여 있었다. `tools/build_xenofauna.py`에서 지지 다리마다 독립 피벗을 만들고 **Blender 원본 40개와 near/far GLB 80개**를 다시 내보냈다. 기존 곡선 다리의 형태·재질·몸통 부착점은 보존했다.

바뀐 카탈로그 필드는 피벗·메시 수·LOD 해시/통계·기하 통계다. 나머지 종 정보와 외형 프로필 파일은 이전 버전과 동일하다. 실제 크기 판정에 사용하는 near 경계 차이는 최대 `1.1920928955078125e-7m`로 출력 부동소수점 오차 범위다. far 모델은 독립 다리마다 다시 감량해 경계가 최대 약 7.7mm 달라졌으며 대표 화면에서 실루엣을 확인했다. [비교 기록과 파일 해시](media/ground-locomotion/provenance.json).

Blender Cycles 대표 원본 렌더를 확인했다: [주름 껍질](media/xenofauna/blender/bio_accordion_shell_01.png), [관절 사슬](media/xenofauna/blender/bio_knuckle_chain_01.png), [꽃잎 사마귀](media/xenofauna/blender/bio_petal_mantis_01.png), [나선 등뼈](media/xenofauna/blender/bio_corkscrew_spine_01.png). 게임 INK 확인은 아래 대표 묶음에 포함한다.

## 기존 저장 호환

카탈로그 전체 바이트를 검사하던 기존 저장 검증이 관절만 바뀐 이번 수정본도 거부하는 문제를 실제 이전 T4 저장에서 재현했다. `catalog_compatibility.json`에 **검토한 이전/현재 카탈로그의 정확한 해시 쌍만** 등록하고 생태 검증에서 이를 사용한다. 알려지지 않은 수정본은 계속 거부한다. 기존 저장 파일이나 은하 매니페스트의 카탈로그 해시를 덮어쓰지 않는다.

변경 전 저장을 그대로 읽어 원산지 매니페스트·생태·남은 체력의 동일성을 확인했고, 별도 경로에 저장한 뒤 다시 읽어도 유지됐다. 테스트 개체의 남은 체력은 333이다. 모델 수정으로 원산지·종 분포를 다시 추첨하지 않는다.

## 실제 확인

환경은 Godot 4.7.2 Forward+ / Metal / Apple M2, Blender 5.2.1 LTS다. 발견된 보행·스킨 축·저장 문제의 재현과 수정 확인에 검사를 한정했다.

| 검사 | 결과와 범위 |
| --- | --- |
| `check_ground_locomotion.gd` | **87개 통과, 실패 0**. 16개 대표 조건에서 느린 이동·4m/s 달리기·17.4m/s 돌진·정지·회전·경사·4배 크기·10Hz 위치 갱신·LOD·재배치·동굴 바닥·5,130종 데이터 연결을 확인했다. 마커뿐 아니라 실제 스킨 발바닥의 위치도 검사한다. |
| `render_ground_locomotion_types.gd` | 구조/컬렉션별 **88개 대표**를 두 LOD로 렌더했다. 지지 중 18cm 이상 접점 오차가 기록된 경우는 0이다. near 15페이지 전체와 far 04·05·06·08·13페이지를 직접 확인했다. |
| 기존 `check_wildlife_tiers.gd --play` | 실제 T4 원정에서 **14개 통과**. 자연 배정된 `biota_saddle_sails_26`의 돌진·피해·총기 반격·경고/타격 음원 호출·저장을 확인했다. 체력 360, 돌진 15.6m/s·11.07m, 피해 35.52, 반격 후 체력 333. 교전 준비는 기존 격리 검사 도구로 설정했다. |
| `check_ground_catalog_compatibility.gd` | **7개 통과**. 현재/이전 해시 허용·미확인 해시 거부·변경 전 실제 저장 읽기·생태/체력 보존·재저장/재로드를 확인했다. |

기록: [보행 수치](media/ground-locomotion/verification.json), [보행 검사](media/ground-locomotion/rules.txt), [88개 대표 접점](media/ground-locomotion/types.json), [실제 T4 교전](media/ground-locomotion/tier-play.txt), [저장 호환](media/ground-locomotion/save-compatibility.txt).

대표 게임 화면: [기존 지상종](media/ground-locomotion/types-00-near.png), [새 독립 다리](media/ground-locomotion/types-06-near.png), [네발 관절](media/ground-locomotion/types-08-near.png), [도약·여러 다리](media/ground-locomotion/types-12-near.png), [먼 모델](media/ground-locomotion/types-13-far.png), [T4 돌진 준비](media/ground-locomotion/tier4-windup.png), [실제 반격](media/ground-locomotion/tier4-hit.png). 전체 대표 near 화면은 같은 폴더의 `types-00`~`types-14`다.

재현 명령은 저장소 루트에서 실행한다.

```sh
python3 tools/bestiary/build_ground_locomotion.py # NumPy가 있는 Python 환경
./tools/godot.sh --headless --script res://tests/check_ground_locomotion.gd
./tools/godot.sh --script res://tests/render_ground_locomotion_types.gd
./tools/godot.sh --headless --script res://tests/check_ground_catalog_compatibility.gd -- --save=/tmp/native-tier-play/world.json
```

## 남은 경계

모든 5,130종에 적용했지만 각 종을 모든 자연 지형에서 개별 플레이한 것은 아니다. 88개 구조 대표와 문제 재현 조건을 확인했다. 사건·새끼 연결은 코드와 공통 모델 구동기를 확인했고, 이번 작업에서 다섯 생물 사건 전체를 다시 완주하지 않았다. 인터넷 다중 클라이언트·장시간 성능·전체 기본 플레이 회귀는 수행하지 않았다.

기존 단일 관절 다리는 뿌리를 고정하고 제한된 균일 크기 보정(0.84~1.12배)으로 접지한다. 이 모델들에 모두 무릎·발목을 새로 제작한 것은 아니다. 검사에서 가장 큰 발 목표 차이는 구형 두발 모델의 발을 드는 구간 약 7.6cm였으며, 지지 중 미끄러짐과 구분한다. 세부 체형의 개별 수작업 애니메이션은 추가 개선 여지가 있다.

바닥 탐색은 발 주변 높이 ±0.25~1.2m의 짧은 범위다. 큰 절벽을 넘어가는 경로 계획·새 벽 타기·전신 물리 균형을 추가하지 않았다. 공격용으로 든 앞발·공중 도약·무력화 자세는 접지에서 풀어 기존 전투 동작을 유지한다.

새 종별 발소리는 제작하지 않았다. 기존 ElevenLabs 음원의 게임 재생 호출을 확인했으며 이번 보행 작업에서 새 음원 생성이나 별도 청감 평가는 수행하지 않았다.
