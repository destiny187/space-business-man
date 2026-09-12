# 지상 무기 발사·착탄·타격음 고도화

2026-09-12 사용자 요청: 지상 무기의 공격 효과와 사운드·타격감을 에이펙스 레전드를 참고해 강화한다. 효과를 크게 키우는 방식은 필요하지 않다. 소관은 [지상전](../game/27-ground-and-flight-combat.md), 표현은 INK v1과 FIELD v1을 유지한다.

## 같은 날 후속 — 피해량과 실드 파괴

사용자는 피해량 숫자와 실드 파괴음·효과도 에이펙스 레전드의 느낌으로 요청했다. 앞선 작업에는 명중 표식만 있었으며, 이번 후속에서 다음을 추가했다.

- 호스트의 `damage_targets`는 적별 실제 체력·실드 감소량과 위치, 약점·파괴·격파 여부를 반환한다. 산탄은 같은 적에 맞은 탄만 하나로 합치며 플라스마의 주변 대상 피해도 각각 기록한다. 과잉 피해와 빗나감에 숫자를 만들지 않는다.
- 자신이 맞힌 적 위에 굵은 외곽선 숫자가 튀어나와 떠오르고 사라진다. 같은 대상에 0.75초 안에 맞힌 실제 피해를 합산하며 마지막 명중 뒤 0.95초 동안 표시한다. 내부 소수는 합산 후 정수로 반올림한다. 대상별 분리·화면 뒤/밖 숨김·메뉴/장비 전환 정리·16개 제한을 적용한다.
- 실드는 파랑, 생물 체력은 붉은색, 로봇 장갑은 회색, 약점은 금색이다. 숫자 옆 실드 윤곽과 갈라진 실드, 격파 꺾쇠를 함께 사용한다. 현재 적 실드에는 희귀도 색상 체계가 없으므로 에이펙스의 모든 실드 등급 색을 추가하지 않는다.
- 실드가 깨질 때 조준점 위 깨진 실드, 숫자 옆 갈라짐과 작게 퍼지는 6개 파편을 연결한다. 실드 파괴와 격파가 같은 발사에서 발생해도 파괴 표현이 격파에 덮이지 않는다.
- 기존 ElevenLabs 원본으로 파괴음의 첫 파열·엇갈린 짧은 조각·꼬리를 재편집했다. 동시에 격파하면 파열 뒤 0.18초부터 낮고 작은 격파 잔향이 붙는다. 기존 발사음 감쇠를 유지한다. 자기 실드 피격/파괴에 쓰이던 건설 효과음도 전용 음원으로 바꾸고 자기 파괴는 낮은 피치와 화면 가장자리 균열로 구분한다.

EA [공식 접근성 안내](https://www.frostbite.com/able/resources/apex-legends/pc/features)의 기본 `Stacking`(최근 피해 합산)과 X/실드 명중 피드백을 참고했다. 색·시간·크기·파열 편집은 이 게임에 맞춘 값이며 외부 게임의 그림·음원을 가져오지 않았다. 적 피해 숫자에 적용하는 색은 플레이어의 청록색 공통 상태 아이콘 규칙과 용도가 다르다.

HP가 아닌 명중 횟수로 해제되는 화물 드론은 기존 명중 표식만 유지한다. 이전 저장에 새 위치/피해 자료가 없는 발사는 숫자를 추측하지 않고 다음 발사부터 표시한다. 숫자 위치는 마지막 확정 타격의 월드 위치이며 사격이 끊긴 뒤 계속 적을 추적하는 표식은 아니다. 표시 방식 선택 메뉴와 인간 적/PvP·실드 등급 추가는 이번 범위가 아니다.

현재 파괴음 2종의 원본 해시·편집값·출력 측정은 [v3 음원 기록](../../audio/manifests/ground-shield-feedback.json), 재생성은 `python3 tools/prepare_ground_shield_feedback.py`가 소관이다. 전체 음원을 재생성할 때 v2 제작 스크립트 뒤에 v3를 실행한다. 신규 ElevenLabs 생성은 하지 않았다. 이전 v2 파괴음 해시는 제작 이력으로 보존한다.

Godot 4.7.2 / Metal Forward+ 실제 창에서 20→40→60 합산, 산탄 1개 합계, 실드/체력 동시 소진 때 실제 남은 피해 2 표시, 작은 화면 약점 숫자, 만료·메뉴 정리·빗나감 억제와 출력 녹음을 확인했다. [파란 실드 피해](media/ground-weapon-feedback/damage-numbers/stack-0.png), [파괴와 합산](media/ground-weapon-feedback/damage-numbers/stack-1.png), [동시 격파](media/ground-weapon-feedback/damage-numbers/break-and-defeat.png), [960×640 약점](media/ground-weapon-feedback/damage-numbers/weak-960.png). 자기 실드는 호스트의 실제 방어 감소 경로로 피격·파괴와 [가장자리 균열](media/ground-weapon-feedback/damage-numbers/own-shield-crack.png), 정상 저장을 확인했다. 자기 실드/저장으로 범위를 좁힌 최종 실행은 [9개 확인, 실패 0건](media/ground-weapon-feedback/damage-numbers/own-shield-corrected.log)이다.

실제 SFX 출력은 공격 [13.50초 녹음](media/ground-weapon-feedback/damage-numbers/runtime-mix.wav) 피크 -10.95dBFS, 자기 실드 [1.40초 녹음](media/ground-weapon-feedback/damage-numbers/own-runtime-mix.wav) 피크 -16.56dBFS이며 둘 다 클리핑 0개다. [검수 메타데이터](media/ground-weapon-feedback/damage-numbers/verification.json), [확정 피해 자료와 시각](media/ground-weapon-feedback/damage-numbers/timeline.json). 주관적 청감·다중 클라이언트·이번 후속의 생물 숫자 화면과 다중 플라스마 대상 동시 배치는 미확인이다. 해당 코드 연결과 실제 검수 범위를 구분한다.

초기 검수는 긴 지형 생성 프레임이 55초 제한을 넘겨 종료됐다. 진단에서는 반환 시 지형/입력이 이미 준비된 상태도 확인했다. 검수 도구가 긴 프레임 이후 준비 조건을 한 번 더 확인하고 최대 120초 기다리게 했다. 시야는 임시 실행에만 1,200m로 제한했으며 지형 코드·사용자 설정 파일은 변경하지 않았다. 이어진 [사격 확인 로그](media/ground-weapon-feedback/damage-numbers/combat-and-fixture-error.log)의 자기 실드/저장 실패는 발생기가 없는 임시 캐릭터에 실드량을 넣었던 검수 자료 문제다. 모듈이 없던 최초 검사 코드 오류도 [보존](media/ground-weapon-feedback/damage-numbers/missing-module-fixture.log)했다. 유효한 발생기를 미리 장착한 임시 자료와 현재 호스트 사본을 사용해 위 자기 실드/저장 범위만 다시 확인했다. 최종 종료에 ObjectDB 2개 경고는 남고 해당 실행의 스크립트/셰이더 오류는 없었다. 아래 45개 확인은 앞선 발사·착탄 작업 기록이며 후속 결과와 합산하지 않는다.

재현: `./tools/godot.sh --script ../tools/media/review_ground_damage_numbers.gd -- --crew-ui-test --crew-folder=/tmp/ground-damage-numbers`. 이미 만든 임시 자료에서는 `--resume-fixture`, 자기 실드만 확인할 때는 추가로 `--own-only`를 사용한다.

## 적용

- 기존 8계열에 짧은 총구 섬광, 얇고 이동하는 탄흔, 총몸 후퇴·상향·좌우 복귀, 볼트/펌프 움직임을 연결했다. 기관단총은 작고 빠르게, 산탄총은 여러 탄흔과 큰 총몸 반응, 정밀총은 길고 얇은 탄흔, 플라스마는 작은 보라색 파열로 구분한다.
- 총구는 기존 Blender `Socket_Muzzle`을 사용한다. 섬광은 약 35~70ms이며 스트리밍으로 프레임이 길어져도 첫 화면에서는 한 번 보이게 한다. 조준경으로 모델을 숨기는 정밀총에는 총구 섬광을 겹치지 않는다. 정밀 조준 중 탄흔은 총구에서 최대 4m 지난 곳부터 표시해 가까운 탄흔이 크게 확대되는 현상을 줄인다. 조명은 기존 총구 등 하나로 제한한다.
- 호스트가 각 산탄의 실제 착점과 실드/파괴/장갑/생물/지형 접촉을 `contacts`로 반환한다. 첫 탄 끝점에 합산 명중 효과를 찍던 경로를 제거했다. 빗나간 일반 탄은 명중 효과·확인음을 만들지 않는다. 발사·명중 표현은 승인된 발사 결과를 받은 뒤 실행한다.
- 실드는 작은 원과 전기 조각, 장갑은 짧은 방향성 불꽃, 생물·지면은 절제된 먼지/입자로 구분한다. 기존 생물 피격 행동은 유지한다. 명중 표식은 짧게 모였다 사라지고, 실드 파괴는 갈라진 호, 격파는 작은 아래쪽 표식을 함께 쓴다. 설명 문구를 추가하지 않았다.
- 효과는 전용 144개 풀을 사용한다. 일반 채집·건설 효과의 풀과 분리했고 메뉴·장비 전환·지상 이탈 때 정리한다. 총기 발사음은 최대 8개 중첩으로 제한한다.

계열별 크기·속도·반동·복귀와 확인음 설정은 `data/firearm_feedback.json`에 있다. 무기 피해·탄창·연사 간격·제작비·획득·소유 저장을 변경하지 않았다. 기존 저장의 `weapon_event`에 `contacts`가 없으면 명중 위치를 추측해서 만들지 않으며 다음 실제 발사부터 새 자료를 쓴다. 접촉 방향은 탄의 역방향으로 근사한다. 지형의 정밀 법선·탄흔 데칼·물 재질별 탄착·느린 물리 발사체는 이번 범위가 아니다.

## ElevenLabs 음원

기존 ElevenLabs 발사 8종의 원본에서 시작 무음을 정리하고 저역/고역·첫 타격·짧은 꼬리를 다시 가공했다. 장갑·생물·실드·약점·실드 파괴·격파 확인음 6종은 같은 원본에서 필요한 부분을 편집·혼합했다. 생물 명중 때마다 긴 비명을 겹치는 대신 짧은 접촉 확인음을 재생하며, 생물 자체의 위치 피격음은 기존 경로를 유지한다.

연사에 ±1.5% 범위의 작은 피치 차이를 적용한다. 명중 순간에는 이미 재생 중인 자기 발사음의 꼬리만 3dB 낮춘다. 적 경고·발소리·다른 SFX의 버스 볼륨은 변경하지 않는다.

- 원래 프롬프트·생성 정보: [원본 목록](../../audio/manifests/ground-combat-sources.json).
- 이번 편집·출처 해시·신호 측정: [v2 편집 이력](../../audio/manifests/ground-weapon-feedback.json).
- 재생성: `python3 tools/prepare_firearm_feedback_audio.py`. 이전 [v1 이력](../../audio/manifests/ground-combat.json)은 보존하며 현재 8계열 파일 해시는 v2가 소관이다.
- 신규 ElevenLabs 생성은 하지 않았다. 기존 생성 원본을 활용한 후속 편집이며 외부 게임의 음원·그림은 가져오지 않았다.

참고한 EA [공식 오디오 설명](https://www.ea.com/games/apex-legends/apex-legends/news/showdown-audio-update)은 정보 전달과 소리 간 가림 감소를, [무기 안내](https://help.ea.com/en/articles/apex-legends/guns-and-weapons/)는 계열별 역할 구분을 설명한다. 짧은 발사 반응·중첩 제한·명중 시 꼬리 감쇠는 이 프로젝트에 맞춘 구현 선택이며 에이펙스의 음원이나 내부 수치를 재현한 것은 아니다.

## 실제 확인과 경계

검수 자료는 `docs/production/media/ground-weapon-feedback/`에 보존한다. 사용자 저장 대신 `/tmp/ground-weapon-feedback`의 기존 검수 시드를 사용한다. 재현 명령은 다음과 같다.

```bash
./tools/godot.sh --script ../tools/media/review_ground_weapon_feedback.gd -- --crew-ui-test --crew-folder=/tmp/ground-weapon-feedback
```

Blender 5.2.1에서 기존 8개 원본과 내보낸 GLB의 해시·총구·볼트·탄창을 확인하고 카빈 가동부를 렌더했다. 모델 원본·GLB는 교체하지 않았다. [Blender 렌더](media/ground-weapon-feedback/blender-carbine-action.png), [원본/출력 기록](media/ground-weapon-feedback/blender-sources.json).

Godot 4.7.2 / Metal Forward+ / Apple M2 실제 창에서 8계열 발사·계열별 음원·각 탄 접촉점, 실드 파괴/장갑/약점/격파, 빗나감, 메뉴 중 음원/효과 정리, 960×640 화면과 임시 원정 저장을 확인했다. 해당 작은 실행 검사 45개는 실패 0건이다. [로그](media/ground-weapon-feedback/play.log), [카빈](media/ground-weapon-feedback/carbine-attack.png), [산탄](media/ground-weapon-feedback/shotgun-attack.png), [플라스마](media/ground-weapon-feedback/plasma-attack.png), [작은 화면](media/ground-weapon-feedback/combat-960.png).

실제 SFX 버스 [25.43초 출력 녹음](media/ground-weapon-feedback/runtime-mix.wav)의 피크는 -10.20dBFS, 클리핑 표본은 0개다. [큐 시각·접촉 자료](media/ground-weapon-feedback/runtime-timeline.json), [신호 측정](media/ground-weapon-feedback/verification.json). 사용 가능한 도구로 출력 재생·녹음 신호를 확인했으며 주관적 청감 평가는 완료로 기록하지 않는다.

실제 자연 배정된 생물에 발사해 `organic` 접촉과 짧은 확인음도 확인했다. [생물 착탄 화면](media/ground-weapon-feedback/organic-impact.png), [추가 출력 녹음](media/ground-weapon-feedback/organic-runtime.wav), [해당 로그](media/ground-weapon-feedback/organic.log). 추가 검수의 지면 발사는 검사 코드가 카메라 갱신 전 방향을 사용해 처음 실패했다. 실제 카메라 방향을 기다리도록 고친 뒤 지면 착탄·조준경의 원거리 탄흔·저장을 대상으로 한 11개 확인은 실패 0건이다. [수정 확인 로그](media/ground-weapon-feedback/terrain-and-scope.log), [지면](media/ground-weapon-feedback/terrain-impact.png), [조준경](media/ground-weapon-feedback/scoped-shot.png). 최초 로딩 직후 생물 메시만 기다리고 지면 충돌/호스트 입력 준비를 기다리지 않았던 검수 오류도 수정했다. 완료 수량에 최초 실패를 합산하지 않는다.

추가 경로 재현: `./tools/godot.sh --script ../tools/media/review_organic_weapon_feedback.gd -- --crew-ui-test --crew-folder=/tmp/ground-organic-feedback`. 지면/조준경만 확인할 때는 `--terrain-only --scope-check`를 덧붙인다.

첫 검수는 임시 표적을 실제 허용 체력/실드보다 높게 설정하고 잘못된 단계 이름을 써 저장 검증에서 중단됐다. 이는 게임 밸런스 변경이 아닌 검수 자료 오류였다. 정상 범위와 단계로 수정한 뒤 위 경로를 다시 확인했다. [최초 실패 로그](media/ground-weapon-feedback/play-initial-fixture-error.log)를 보존한다. 검수 장면 종료에는 ObjectDB 인스턴스 1~2개 경고가 남았고, 최종 사격 실행에 스크립트/셰이더 오류는 없었다. 다중 클라이언트·장시간 전투·전체 회귀는 실행하지 않았다.
