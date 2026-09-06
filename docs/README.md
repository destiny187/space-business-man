# 게임 설계 문서 목차

루트 진입점: [AGENTS.md](../AGENTS.md). 이 문서 묶음은 사용자의 최초 아이디어와 설계 초안을 시스템별로 보존한다. 현재 로컬 1.2 구현은 [구현 현황](planning/03-implementation-status.md), 실제 사용법은 [실행 안내](release/01-playing-and-building.md)를 기준으로 확인한다.

## 상태 표기

| 표기 | 의미 |
| --- | --- |
| 확정 요구사항 | 사용자가 직접 제시한 게임 방향과 기능 |
| 원안 예시 | 사용자가 설명에 사용한 사례·수치. 콘텐츠 및 밸런스 확정과는 구분 |
| 설계 제안 | 일관된 구현을 위해 추가한 초안. 사용자 승인 전까지 변경 가능 |
| 미정 | 선택에 따라 구현 비용·경험이 크게 달라지는 항목 |

아래 문서에서 ‘설계 제안’ 절의 규칙·수치·데이터 구조는 모두 제안이다. 구체적이라는 이유만으로 확정 요구사항이 되지 않는다. 코드 구현 상태와 기획 상태도 별개다.

## 읽는 순서와 소관

| 문서 | 담당하는 내용 |
| --- | --- |
| [게임 비전과 핵심 루프](game/01-vision-and-loop.md) | 세계관, 플레이어 역할, 재미의 중심, 한 회차의 흐름 |
| [행성·자원·건축](game/02-planets-resources-and-building.md) | 행성 특성, 수동 채집, 자원, 시설 배치, 초반 경험·화면 |
| [로봇·자동화](game/03-robots-and-automation.md) | 제작, 랜덤 등급·특성, 작업·운반·전력·고장 |
| [테라포밍·행성 판매](game/04-terraforming-and-sales.md) | 환경 상태, 설비 효과, 평가 등급, 매각 절차·가격 |
| [경제·기술·계승](game/05-economy-and-progression.md) | 계정 자산, 기술 상점, 행성 구매, 로봇 회수·수송 |
| [탐험·이벤트·문명](game/06-exploration-and-civilizations.md) | 발견 종류, 보상, 선택과 장기 결과 |
| [아트·Blender 제작](production/01-art-and-blender.md) | 카툰 표현, 에셋 목록, 제작·복구·내보내기 과정 |
| [1.2 렌더링 품질과 성능](production/03-rendering-and-performance.md) | 조명·그림자·접지 음영·재질·Blender 암벽·프리셋·실측 비교 |
| [데모 이후 렌더링 품질 연구](production/04-visual-target.md) | 신규 모델·배경을 포함한 독립 고품질 장면, 실행·조작·검토 범위 |
| [사운드·ElevenLabs 제작](production/02-audio-and-elevenlabs.md) | 사운드 방향, 우선 목록, 프롬프트, 생성·검수 과정 |
| [Godot 기술 설계](technical/01-godot-architecture.md) | 현재 저장소, 제안 구조, 시뮬레이션 경계, 성능·검증 |
| [데이터·세이브 설계](technical/02-data-and-save.md) | 정의와 인스턴스, 식별자, 저장 범위, 중복 방지 |
| [MVP와 개발 단계](planning/01-mvp-and-roadmap.md) | 첫 완결 루프, 단계별 산출물·완료 조건, 확장 순서 |
| [결정 대기 항목과 위험](planning/02-decisions-and-risks.md) | 확정사항 추적, 큰 미정 항목, 위험, 결정 이력 |
| [실제 구현 현황과 검증](planning/03-implementation-status.md) | 코드·에셋·검증 근거·실행 범위 |
| [원안 요구사항 인수 표](planning/04-requirement-audit.md) | R-01~R-19별 실제 제공 결과 |
| [1.1 인터페이스·연출·입문 경험](planning/05-interface-and-feedback.md) | 사용자 피드백 반영, 실제 동작 효과, 단계별 시작 |
| [실행·운영 안내](release/01-playing-and-building.md) | 실행·조작·저장·문제 해결·빌드·라이선스 |

## 문서 유지 규칙

- 시스템 규칙은 소관 문서가 기준이다. 다른 문서는 내용을 재정의하지 않고 연결한다.
- 원안 예시에는 철 100·구리 10의 로봇 제작, 충격 피해 20% 감소 특성, 산소 생성력 55의 미생물이 있다. 모두 의미를 보존하되 실제 수치 확정은 플레이 검증 후 한다.
- 초기 설계는 싱글플레이 로컬 시뮬레이션을 제안한다. 멀티플레이, 구형 월드, 복셀 파괴 지형, 시점은 원안의 확정사항이 아니다.
- 제작·기술 문서의 폴더와 에셋 목록은 목표 설계이며, 생성된 산출물 목록이 아니다.
- 게임 규칙 변경 시 관련 화면, 데이터·저장, 완료 조건도 함께 점검한다.
