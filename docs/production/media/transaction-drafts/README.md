# 거래·지역 초안 검사 근거

Godot 4.7.2 / Apple M2 / Forward+ / Metal, 별도 복사한 Regulus 착륙 저장과 새 검사 세계를 사용했다. 정상 사용자 저장은 변경하지 않는다.

- `request-verification.txt`, `request-metrics.json` (최종), `request-first-verification.txt`, `request-first-metrics.json` (최초 확인): 일반 거래의 저장 실패·재전송·오래된 대기 요청·이동 보존.
- `drafts-verification.txt`, `draft-metrics.json`: 원본의 모든 중첩 자료를 읽기 전용으로 고정하고 기존 전체 초안과 날씨/사건 결과 비교. 피해·구조·엄폐물·지형·다음 물/생태 갱신의 범위 검사. 무관한 이력 10,000건의 합성 자료는 복사 비용 비교에만 사용하며 유효 저장이나 게임 규모 벤치마크로 취급하지 않는다.
- `autonomous-verification.txt`: 체크포인트 순서·대기 요청·저장 실패·이동 중 로버 유지.
- `mining-verification.txt`: 기존 채광의 중복 지급 방지·실패 원본 보존.
- `publication-verification.txt`: 실패·영수증 재전송·대기열 완료의 스냅샷/지표 발행 범위.
- `ui-verification.txt`, `ui-metrics.json`, `selected-tool.png`: 1280×800 실제 창. 핫바 선택, 의도적으로 완료를 늦춘 4개 렌더 프레임, 유료 장비 제작과 일반 명령, 영수증 재전송·저장 파일 확인. 종료 시 ObjectDB 1개 누수 경고를 기록했다.

실행 소스는 `우주-비즈니스/tests/check_request_commit.gd`, `check_world_drafts.gd`, `check_request_commit_ui.gd`, `check_autonomous_save.gd`, `check_mining_commit.gd`, `check_action_publication.gd`다. 실제 창은 `--crew-ui-test --crew-folder=<world.json과 profile.json을 복사한 별도 폴더 절대 경로>`로 실행한다. 초안/거래/채광 검사는 `--source-folder=<원본 검사 복사본>`과 다른 `--crew-folder=<출력 폴더>`를 사용한다. 모든 원시 기록은 로컬 `output/transaction-scope-20260912/`에도 있다.
