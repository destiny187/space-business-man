# 초기 8칸 아이템창

2026-09-07 사용자 요청으로 48칸의 초기 수납을 8칸으로 줄였다. 실제 규칙은 [아이템·제작·장착](../game/13-inventory-and-equipment.md#2026-09-07--초기-8칸과-추후-수납-확장)에 둔다.

## 구현

`inventory.json`의 기본 수납 8과 기존 저장 검사 상한 48을 분리했다. `FrontierItemInventory.capacity(member)`는 `loadout.inventory_slots`를 읽고 구 저장에는 기본값을 적용한다. 여유 공간·화물 인수·장비 제작과 UI는 개인별 값을 공유한다. 확장 구매·재료·가격은 추가하지 않았다.

아이템창은 항상 아이템 탭부터 열리고 1280×800·960×640에서는 4×2로 표시한다. 실제 Blender 장비의 기존 INK 미리보기·선택/끌어놓기·번호 슬롯 5개·제작/공동 창고 탭은 유지한다. 현재 수납량은 짧게 표시하고 자원 중첩·장착 장비의 칸 사용 설명은 툴팁에 둔다. 초과 저장은 모든 아이템을 표시하고 용량 표시를 주황색으로 바꾼다. 수납 막대가 최대치에서 멈춰도 정확한 초과 수량은 텍스트에 남긴다.

UI 확인에서 첫 개방 시 갱신 전의 빈 데이터를 보고 제작 탭으로 이동하던 기존 문제를 발견해 기본 진입 탭을 바로잡았다. 작은 화면에서 2×4로 스크롤되던 배치도 실제 탭 너비에 맞춰 4×2로 보정했다.

## 최소 확인

Godot 4.7.2 / Metal Forward+ / Apple M2의 실제 원정 창에서 `check_inventory_capacity.gd` **14개 확인, 실패 0**. 새 캐릭터 8칸·4×2/번호 슬롯·960px 전체 칸 가시성, 7개 자원 스택+기본 장비, 스택 마지막 1개 인수, 9번째 칸 거절과 공동 재고 보존, 구 저장 900개 보존/저장·10/8칸 표시·추가 수령 차단·반납, 개인 용량 필드 16칸의 화면/거래/저장 연결, 비정수 용량 거절과 종료 저장을 확인했다.

임시 세계에서 선내 보관함 위치·공동 재고와 구 저장 상태를 직접 구성했다. 16칸은 후속 연결점 확인용 상태이며 실제 업그레이드를 구매한 결과가 아니다. 지표 착륙·채광·제작·회수 화물의 실제 창 흐름, 6인 협동·전체 회귀는 반복하지 않았다. 이 경로들이 사용하는 공통 용량 계산 및 제작 판정은 수정했지만 이번 실행 확인 범위와 구분한다. 신규 모델·음원 제작은 없다.

[1280×800](media/eight-slot-inventory/inventory-eight-1280.png) · [960×640](media/eight-slot-inventory/inventory-eight-960.png) · [기존 초과 보관](media/eight-slot-inventory/inventory-legacy-overflow.png)

```bash
mkdir -p /tmp/space-inventory-review
./tools/godot.sh --script res://tests/check_inventory_capacity.gd -- --crew-ui-test --crew-folder=/tmp/space-inventory-review
```
