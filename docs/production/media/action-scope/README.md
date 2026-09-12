# 실행 근거

원본 저장을 건드리지 않도록 `world.json`과 `profile.json`을 별도 폴더에 복사해 사용한다. `--crew-ui-test --crew-folder=<복사본 폴더의 절대 경로>` 없이 실제 창 검사를 실행하지 않는다.

- `before.json`: 수정 전 실제 창의 국소 호출 시간·노드 교체·실패 발행 횟수.
- `first-fix.json`, `final.json`, `verified.json`: 첫 수정, 카드 재사용, 최종 갱신 키 검사. 후속은 새 변경의 확인이며 FPS 벤치마크 반복이 아니다.
- `ui.log`, `crafting.png`, `cargo.png`: 최종 `tests/check_action_scope_ui.gd` 실행과 실제 창.
- `publication.log`: `tests/check_action_publication.gd`의 실패/재전송/오래된 상태/대기실/비동기 경계 확인.
- `mining.log`: 기존 `tests/check_mining_commit.gd`의 저장 실패·중복 지급·이동 보존 확인.
- `transactions.log`, `transactions.json`, `check_transactions.gd`: 슬롯 선택의 전체 저장 시간과 캐시 경계 검사. `--audit-folder=<별도 폴더>`로 실행하며 그 폴더의 `before/world.json`, `before/profile.json`을 읽고 `transaction-world.json`에만 쓴다.

수정 전 전체 작업 복사본, 실행 스크립트와 원시 로그는 로컬 `output/action-scope-audit-20260912/`에도 있다. 화면 검사 중 수량과 무관한 지역 데이터 10,000항목을 지역 표시 복사본에 추가해도 화물 갱신 키가 변하지 않는 것을 확인했다. 원본 세계나 정상 사용자 저장에 추가한 데이터가 아니다.
