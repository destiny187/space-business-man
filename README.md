# 우주 비즈니스맨

모델·음원·이미지는 **Git LFS**로 관리한다. 새 작업 환경에서는 Git LFS 설치 후 `./tools/setup_assets.sh`로 에셋을 받은 뒤 실행한다. [저장 방식과 생성 결과 정책](docs/technical/05-asset-version-control.md).

하나의 은하에서 테라포밍할 행성을 찾아 탐험하고, 발견을 연구해 로봇·생물·시설로 환경을 바꾸는 Godot 게임을 지향한다. 혼자 또는 **호스트 포함 최대 6명**이 각자의 캐릭터·소유 장비를 유지하고 같은 우주선으로 함께 탐험하는 [협동 설계](docs/game/12-host-coop-and-crew.md)를 추가했다. 티어·시드 행성, 우주선 성장, 광활한 지표·지하, 표본 이식, 외계문명과의 협상·거래·갈등을 [탐험 중심 고도화 설계](docs/planning/06-exploration-expansion-roadmap.md)에 추가했다. 확장 기능은 아직 미구현이다.

현재 실행판은 로컬 싱글플레이로 행성을 구매해 원격 장비로 채집하고, 로봇·시설로 테라포밍한 뒤 판매하는 기존 사업 루프다. 좋은 로봇을 지구로 회수해 다음 행성에 데려갈 수 있다.

**플레이 가능한 로컬 1.2 실행판**을 제공한다. 행성 3종, 자원 5종, 시설 9종, 로봇 3모델·3등급, 기술·희귀 상점·수송 계승, 유적·미생물·동물·문명 선택이 연결되어 있다. Blender 모델 27종과 ElevenLabs 음원 16종을 포함한다.

## 이번 개선

하늘 환경광·접지 음영·부드러운 그림자, 재질별 금속·도장 반사, 설비 발광과 가까운 지역 광원을 보강했다. 지면 요철·수면 물결·물가 거품·구름과 위성 무늬를 추가하고, 반복 원뿔 배경을 Blender 암벽 3종으로 교체하고 태양광 패널의 원거리 표면도 보강했다. 설정에서 **성능 우선·균형·높음**을 즉시 선택하고 저장할 수 있다.

[1.2 개선 방안·적용 결과·비교 화면·성능](docs/production/03-rendering-and-performance.md)

![1.2 실제 게임 화면](docs/production/media/1.2-materials.png)

기존 HUD·15단계 개척 가이드·흡입·펄스·로봇 동작은 유지된다. [1.1 개선 기록](docs/planning/05-interface-and-feedback.md) · [1.1 플레이 영상](builds/media/gameplay-1.1.mp4)

## 실행

- **Windows 64비트 ZIP:** [Locus-1.2.0-Windows-x64.zip](builds/windows/Locus-1.2.0-Windows-x64.zip) — 모두 압축을 풀고 `Locus.exe` 실행. Godot 설치 불필요.
- **macOS 앱:** [Locus.app](builds/macos/Locus.app) — 편집기 없이 실행. 표시 이름은 우주 비즈니스맨이다.
- **macOS ZIP:** [Locus-Space-Business.zip](builds/macos/Locus-Space-Business.zip).
- **소스 실행:** `./tools/godot.sh`, 또는 Godot 4.7.2에서 [project.godot](우주-비즈니스/project.godot)를 열고 F5.

Windows에서 기본 실행이 안 되면 함께 넣은 `Start-Vulkan.cmd`를 사용한다. 실행 안내·오류 로그 실행기·라이선스도 ZIP에 포함했다. Windows 실기 실행은 아직 검증하지 않았다. macOS에서 새로 압축을 푼 앱은 첫 실행 준비에 약 1분이 걸릴 수 있다.

WASD 이동, Shift 질주, Space 점프, 마우스 시점, 좌클릭 흡입, 우클릭 펄스, E 반납·조사, B 건축, R 로봇, T 기술, J 탐사, P 평가, V 관찰, F1 도움말, Esc 메뉴, F5 저장. 건축 중 Q 회전·우클릭 취소. 설정에서 키를 변경할 수 있다.

첫 위성을 구매하고 철·구리·암석을 기지로 운반한다. 입문 로봇공학을 구매한 뒤 발전기·충전 패드·제작기를 설치하고 첫 로봇을 만든다. 메뉴를 열면 시간이 멈추며, 도움말이 사업 단계를 안내한다.

## 문서와 검증

- [루트 작업 지침 — AGENTS.md](AGENTS.md)
- [전체 설계 문서 목차](docs/README.md)
- [실행·저장·문제 해결·빌드](docs/release/01-playing-and-building.md)
- [구현 현황과 검증 범위](docs/planning/03-implementation-status.md)
- [원안 요구사항 인수 표](docs/planning/04-requirement-audit.md)

```bash
./tools/test_game.sh --with-ui
./tools/godot.sh --script res://tests/capture_ui.gd
./tools/godot.sh --script res://tests/benchmark.gd
./tools/build_macos.sh
python3 tools/verify_macos.py
./tools/build_windows.sh
python3 tools/verify_windows.py
```

813개 확인 항목을 통과했다. 추가 자원 지급 없이 세 행성을 S등급으로 판매하는 도메인 검증과 실제 창의 입력 검증을 구분해 수행했다. 측정·화면은 `test-results/`에 생성된다.

macOS Apple M2에서 실행·렌더링을 확인했다. 앱은 arm64/x86_64를 포함하는 로컬 ad-hoc 서명본이며 Apple 공증·스토어 등록은 수행하지 않았다. `builds/`는 Git에서 제외되므로 다른 체크아웃에서는 빌드 스크립트로 생성한다.
