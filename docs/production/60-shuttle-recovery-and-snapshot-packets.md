# 이탈 FINCH 회수·협동 스냅샷 분할

2026-09-08 사용자 승인 두 작업을 현재 원정에 구현했다. 소형선 규칙은 [항성계 소형선·분산 생산](../game/18-local-shuttles-and-distributed-industry.md), 통신 규칙은 [협동 네트워크](../technical/04-coop-networking-and-session-save.md)를 따른다. 커밋·패키지 배포·인터넷 품질 완료를 뜻하지 않는다.

## 회수 화면과 거래

P 승무원 창에서 연결이 끊긴 출동자의 FINCH를 선택하고 **공동 원정선으로 회수**한다. 기존 Blender FINCH의 INK 미리보기, 소유자·접속 상태·사용 화물 칸과 복귀 결과를 표시한다. 호스트만 실행하며 접속 중·참가 동기화 중·조립 중·이미 합류한 선박에는 적용하지 않는다. 호스트 자신이 FINCH 출동 중이면 공동선에 먼저 합류해야 한다.

`shuttle_recall`은 기존 요청 순번·세계 리비전·수령 기록·저장 후 공개를 사용한다. 선박 상태를 docked로 바꾸고 승무원의 출동 문맥을 해제한다. 공동선 위치로 복귀하지만 공동 화물로 자동 하역하지 않는다. 소형선 화물·보관 장비, 개인 가방·장착 상태·기존 손 운반 암석과 소유 ID를 보존한다. 다른 행성의 창고·기지·이미 떨어진 회수 상자는 움직이지 않는다. 다른 출동/조립이 남아 있으면 공동 출항은 계속 기다린다.

회수된 승무원은 재접속 때 현재 공동선의 선내 또는 착륙지로 생성된다. 재접속 전 호스트 종료/재시작에서도 가방을 일반 이탈 상자로 떨구지 않도록 `shuttle_recalled`를 저장하고, 참가 저장 성공 시 해제한다. 재접속 자격은 기존 토큰을 유지한다.

승무원 창을 스크롤 가능한 620px 이내 화면으로 조정했다. 요청 중·성공·실패를 구분하며, 기존 ElevenLabs `sfx_factory_complete`/`sfx_build_invalid`를 호스트 응답에 연결했다. 새 모델·음원 제작이나 구조선의 물리 이동 연출은 추가하지 않았다. 메뉴 중 현장 입력/작업음 차단과 숨겨진 미리보기 렌더 중단을 유지한다.

[960 회수 화면](media/shuttle-recovery/recall-960.png) · [1280 회수 화면](media/shuttle-recovery/recall-1280.png) · [회수 완료](media/shuttle-recovery/recalled-960.png).

## 반복 스냅샷 전송

기존 큰 Dictionary RPC를 타입을 보존하는 Variant 바이트→DEFLATE 압축→최대 900바이트 조각으로 바꿨다. 세션 ID·스냅샷 순번·조각 번호/총수로 재조립하고 완전한 스냅샷만 기존 검증 후 적용한다. 오브젝트 역직렬화는 허용하지 않는다. 채널 2를 비신뢰·비순서 전송으로 사용해 조각 순서가 뒤바뀌어도 조립한다. 조각 유실은 다음 전체 스냅샷으로 복구하며 재전송 대기로 입력을 막지 않는다.

원본 512KiB·압축 128KiB·미완성 최대 3개·1초 만료를 제한한다. 완료된 순번 이하를 폐기하고 새 세션 제안에서 조립 상태와 수신 순번을 초기화한다. 수치는 `crew.json`과 전송 클래스에 있으며 실제 대규모 대역폭 보장값이 아니다. 900바이트는 조각 데이터 크기이며 RPC/ENet/UDP 헤더를 포함한 wire 크기와 구분한다.

프로토콜은 3으로 갱신한다. 채널 0은 참가/거래/응답, 1은 입력, 2는 반복 스냅샷, 3은 신뢰 지표 기록으로 분리했다. 초기 참가 상태와 지표 자체의 증분 전송까지 재설계한 것은 아니다. 큰 상태에서 전체 스냅샷을 계속 압축하는 CPU 비용·6인 다거점 대역폭은 후속 측정 범위다.

## 발견한 호환 문제

실제 ENet 확인의 첫 실행에서 기존 은하의 참가가 ‘은하 생성 정의 오류’로 거절됐다. 새 동굴 규칙이 없는 과거 manifest를 현재 기본 규칙과 비교하면서 생긴 문제였다. 없는 `underground_rules`는 참가 검사에서도 추가하지 않도록 수정했다. 기존/신규 manifest 검사를 통과하고 같은 기존 세계의 실제 접속을 다시 확인했다. 저장 지형을 새 동굴로 변환하지 않는다.

## 실제 확인

- `check_shuttle_recovery_packets.gd`: 최종 34개 실패 0. 접속 중/게스트/재접속 처리 중 거부, 저장 실패 원자성, 동일 요청 재시도·중복 회수, 가방/화물/보관 장비/손 운반 암석 보존, 출항 대기 조건 해제, 호스트 종료/재시작·소유자 재접속, 기존/새 은하 manifest, 조각 역순·유실·늦은 도착·메모리/만료 경계를 확인했다. 첫 실행의 검사 준비 데이터가 장비 정의 문자열을 Dictionary로 취급한 오류는 검사만 수정했다.
- `check_shuttle_recovery_ui.gd`: 실제 Godot 4.7.2 / Metal Forward+ / Apple M2, 1280×800·960×640에서 9개 실패 0. 현재 원정 진입, FINCH 렌더·대상 선택·실제 호스트 버튼 거래·화물 보존·메뉴 차단·숨김 렌더 중단·저장 재읽기를 확인했다. 캡처를 직접 검수했다. 실제 재생 연결을 재사용했으며 주관적 청음 완료로 기록하지 않는다.
- `check_snapshot_peer.gd`: 같은 Mac의 별도 ENet 호스트/게스트 프로세스 모두 PASS. 기존 분산 세계 참가→반복 스냅샷 수신 순번 15→개인 소형선의 다른 행성 지표 기록 수신을 확인했다. 최대 조각 데이터 900바이트, 최종 실행에 MTU 초과·스크립트 오류·종료 누수 경고 없음. 인터넷이나 실제 패킷 손실 환경 검증이 아니다.
- 예시 상태: 원본 Variant 7,248바이트→압축 1,881바이트→3조각. 토큰 등 상태에 따라 압축 크기는 달라질 수 있다. 전체 회귀·6인/인터넷·Windows·장시간 성능 검사는 실행하지 않았다.

[검사 로그](media/shuttle-recovery/domain.txt) · [화면 검사](media/shuttle-recovery/ui.txt) · [ENet 호스트](media/shuttle-recovery/host.txt) · [ENet 게스트](media/shuttle-recovery/guest.txt) · [전송 계측](media/shuttle-recovery/network.json).

검사는 사용자 저장과 분리한 `/tmp/finch-sortie` fixture를 사용한다. 없으면 기존 `check_planet_supply.gd` → `check_shuttle_sortie.gd`로 준비한다. 도메인 검사는 `./tools/godot.sh --headless --script res://tests/check_shuttle_recovery_packets.gd`, 화면은 `./tools/godot.sh --script res://tests/check_shuttle_recovery_ui.gd -- --crew-ui-test --crew-folder=/tmp/shuttle-recovery-ui`로 실행한다. ENet 검사는 fixture 세계/프로필을 `/tmp/snapshot-peers`에 복사해 `world.json`, `host.json`, `guest.json`으로 준비하고 호스트/게스트의 `--packet-role=host`, `--packet-role=guest`를 별도 프로세스로 실행한다. 포트는 격리 확인용 24617이다.
