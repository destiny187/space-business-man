# 실행·운영 안내

## 바로 실행

**Windows:** [Locus-1.2.0-Windows-x64.zip](../../builds/windows/Locus-1.2.0-Windows-x64.zip)을 모두 압축 풀기한 뒤 `Locus.exe`를 실행한다. Godot 편집기 설치가 필요 없다. Intel·AMD x64 PC용이며 `Locus.pck`를 실행 파일 옆에 유지한다. 기본은 Direct3D 12 / Forward+다. 실행에 문제가 있으면 `Start-Vulkan.cmd`로 Vulkan / Forward+를 사용한다. 두 실행 방식은 같은 세이브와 화질 설정을 사용한다.

Windows ZIP에는 한국어 `README.txt`, 로그를 남기는 `Start-Diagnostics.cmd`, 라이선스와 구성 파일 해시가 포함된다. 로그 실행기는 `%TEMP%\Locus-Windows-test.log`에 기록하고 게임 종료 후 경로를 표시한다. 개발 테스트용으로 배포자 코드 서명을 적용하지 않았다. Windows 실기 실행·드라이버·프레임 성능은 미검증이며, 패키지 검증 결과와 macOS에서의 게임 검증을 구분한다.

**macOS:**

[`builds/macos/Locus.app`](../../builds/macos/Locus.app)를 연다. Finder와 게임의 표시 이름은 **우주 비즈니스맨**이다. Godot 편집기를 설치하지 않아도 실행된다. 전달용 압축 파일은 [`Locus-Space-Business.zip`](../../builds/macos/Locus-Space-Business.zip)이다.

새로 압축을 푼 앱은 첫 실행 준비에 약 1분이 걸릴 수 있다. 이번 1.2 최종 독립 실행 검증은 8.05초였고, 앞선 실행에서는 42~73초도 관찰했다. 이 수치는 장면을 4초 동안 표시하고 종료하는 시간을 포함하며, 매번 같은 시작 시간을 보장하지 않는다.

소스로 실행하려면 저장소 루트에서 `./tools/godot.sh`를 사용하거나 Godot 4.7.2로 `우주-비즈니스/project.godot`를 열고 F5를 누른다. 실행 도구는 설치된 Godot를 찾으며 `GAME_GODOT_BIN` 환경변수로 경로를 지정할 수 있다.

## 첫 사업

1. 새 사업을 시작하고 모래빛 위성을 구매한다.
2. WASD·마우스로 이동·시점을 조작하고 주변 철·구리·암석 광맥을 좌클릭으로 채광한다. 화물 한도는 140이다.
3. 기지 근처에서 E로 반납한다. T에서 입문 로봇공학을 구매한다.
4. B에서 태양광 발전기·충전 패드·로봇 제작기를 배치한다. Q로 회전하고 좌클릭으로 설치, 우클릭으로 취소한다.
5. R에서 철 100·구리 10으로 첫 채광로봇을 주문한다. 현장에 돌아가면 제작 시간이 진행된다.
6. 기술과 자원을 모아 대기·온도·물·생태 설비를 세운다. 물 순환기는 얼음을 소모한다. 시설의 대기 이유와 발전량을 확인한다.
7. J와 레이더로 발견을 찾아 조사한다. P에서 환경 목표·등급·판매 금액을 확인한다.
8. 궤도 회수 기술과 우주선을 마련하고 판매 전에 좋은 로봇을 선택한다. 다음 행성 구매 전에 지구 보관소에서 출발 편성을 고른다.

좌클릭은 광물 흡입, 우클릭은 펄스 파쇄·사격이다. 연속 발사하면 과열되어 냉각 후 재개한다. 건설 중 우클릭은 배치 취소이며 발사하지 않는다. 새 사업은 15단계 개척 가이드를 제공하고 F1에서 숨기거나 재개할 수 있다.

Shift 질주, Space 점프, V 관찰 카메라, F1 도움말, F5 저장, Esc 메뉴다. 메뉴를 열면 시간이 멈춘다. 설정에서 키·감도·음량·전체 화면을 바꿀 수 있다.

## 그래픽 품질

1.2는 설정의 그래픽 품질에서 ‘성능 우선·균형·높음’을 즉시 선택한다. 기본은 균형이다. 높음은 화면 간접광·반사와 부드러운 태양 그림자를 더하며 GPU 부하도 커진다. 화면이 끊기면 균형이나 성능 우선으로 낮춘다. 설정·진행 저장을 누르면 다음 실행에도 적용된다. 이전 세이브에 새 설정이 없어도 불러올 수 있다.

[적용 내용·프리셋 비교·측정 한계](../production/03-rendering-and-performance.md)를 참고한다.

## 진행이 멈췄을 때

| 상황 | 해결 |
| --- | --- |
| 화물이 가득 참 | 기지나 보관함 근처에서 E로 반납 |
| 보관함이 한 자원으로 가득 참 | 저장고 확장 또는 로봇/일시정지 메뉴의 보관함 관리에서 초과분 폐기 |
| 충전 대기 | 켜진 충전 패드와 충분한 발전량 확보 |
| 경로 없음·파손·배터리 고갈 | 시설 배치를 확인하고 로봇 메뉴에서 기지 회수·수리 |
| 제작 시간이 흐르지 않음 | 현장으로 돌아가고 제작기에 전력을 공급 |
| 얼음 부족·생태 조건 대기 | 얼음 공급, 대기·온도·물부터 개선 |
| 등급이 C에서 멈춤 | 대기·온도·물 적합도 각각 60 이상을 120초 유지 |
| 문명 작전 때문에 판매 불가 | 경비로봇 작전을 완료하거나 중단된 로봇을 구조 |
| 사업 자금·진행 복구 필요 | 일시정지 메뉴의 사업 안전 시작점 복구. 현재 회차 구매·보상·진행을 되돌림 |

## 저장

일반 저장은 `user://campaign.json`, 정상 백업은 `campaign.json.bak`이다. 실제 절대 경로는 게임 설정에서 확인한다. macOS에서는 `~/Library/Application Support/Godot/app_userdata/우주 비즈니스맨/`, Windows에서는 `%APPDATA%\Godot\app_userdata\우주 비즈니스맨\` 아래에 저장된다.

현장은 60초마다 저장하고 구매·판매·제작 완료 같은 중요 작업도 저장한다. 새 사업 시작은 기존 기록 교체를 확인한다. 손상된 기본 파일은 정상 백업으로 복구한다. 백업까지 잘못됐으면 기존 파일을 덮어쓰며 불러오지 않는다.

## 빌드와 제작

`./tools/build_windows.sh`는 공식 4.7.2 Windows x64 템플릿을 사용해 깨끗한 임시 폴더에 내보내고, 안내·실행기·고지·해시를 추가해 ZIP을 생성한다. 콘솔 실행기도 포함한다. 결과는 `builds/windows/Locus-1.2.0-Windows-x64.zip`이며 SHA-256은 같은 폴더의 `SHA256SUMS.txt`에 기록한다. 템플릿은 Godot의 내보내기 템플릿 관리에서 설치한다.

`python3 tools/verify_windows.py`는 ZIP을 별도 임시 폴더에 풀어 CRC, 파일 해시, PE x64 아키텍처·버전·GUI/콘솔 구분, PCK의 모든 리소스 MD5와 모델·음원 포함 여부를 검사한다. `--godot /절대/경로/Godot`를 추가하면 해당 호스트 엔진으로 추출한 PCK를 렌더링·캡처·종료한다. 이는 Windows EXE를 실행하는 검사가 아니며 결과는 `test-results/windows-release.json`에 구분해 기록한다. 사용자 저장은 쓰지 않는다.

Windows 템플릿의 SHA-512는 [공식 4.7.2 릴리스 체크섬](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt)과 대조했다. 별도 Agility SDK DLL이 없는 공식 템플릿은 Windows 시스템 D3D12 로더를 사용한다. 관련 엔진 동작은 [4.7.2의 D3D12 초기화 코드](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/d3d12/rendering_context_driver_d3d12.cpp)에 따른다. DLL을 임의 다운로드해서 추가할 필요는 없다.

`python3 tools/verify_macos.py`는 완성된 ZIP을 새 임시 폴더에 풀어 서명·버전·독립 실행·화면 캡처·종료를 검사한다. 사용자 사업 저장은 쓰지 않는다.

`./tools/build_macos.sh`는 공식 4.7.2 macOS 템플릿으로 앱을 내보내고 내부 실행 파일·PCK 이름을 ASCII로 정리한 뒤 macOS의 `codesign`으로 ad-hoc 서명·검증한다. 게임명·설정명은 한국어로 유지한다. 템플릿 설치 위치는 `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`이다.

배포 대상 아키텍처는 arm64/x86_64다. ZIP의 SHA-256은 [SHA256SUMS.txt](../../builds/macos/SHA256SUMS.txt)에 기록한다. `builds/`는 재생성 가능한 결과이므로 Git에서 제외한다. 공식 공증이나 스토어 업로드를 대신 수행하는 스크립트는 아니다.

Blender 원본은 `art/blender/`, 게임용 모델은 `우주-비즈니스/assets/models/`에 있다. `tools/build_assets.py`로 기본 모델을, `tools/build_landscape.py`로 1.2 암벽 모델을 재현한다. Blender가 종료되면 [재실행 규칙](../../AGENTS.md)을 따른다.

ElevenLabs 음원 16종은 이미 포함되어 있다. `python3 tools/generate_audio.py`는 현재 상태를 표시하는 dry run이다. `--generate`를 사용해도 기존 WAV/MP3는 보존하고 새 생성 요청을 보내지 않는다. 향후 미생성 항목의 API 생성에는 로컬 환경의 `ELEVENLABS_API_KEY`가 필요하다.

## 포함된 고지

- Noto Sans KR: [OFL](../../우주-비즈니스/assets/fonts/OFL.txt), [원본과 해시](../../우주-비즈니스/assets/fonts/sources.json).
- Godot: [MIT 라이선스](../../우주-비즈니스/assets/legal/Godot-LICENSE.txt), [의존성 저작권 고지](../../우주-비즈니스/assets/legal/Godot-COPYRIGHT.txt).
- ElevenLabs: [각 음원의 생성 프롬프트·웹 기록·선택본·편집 정보](../../audio/manifests/elevenlabs.json).

## 공동 지표 탐험 실증

새 탐험 경로는 [공동 지표 안내](../production/12-shared-surface-and-ecology.md)를 따른다. 공동 항해 후 전원 준비→착륙, `E` 유지 스캔·`Q` 표본·클릭 굴착, 우주선 주변 공동 창고/연구/격리 작업, 전원 복귀·준비→이륙을 제공한다. 같은 프로토콜 2/콘텐츠로 참가해야 하며 저장은 호스트의 `crew_world.json`, 개인 장비는 별도 프로필이다. 단독 탐험 저장을 자동 병합하지 않는다. 직접 UDP 접속이며 Steam 로비·자동 중계·호스트 이전은 미지원이다.
