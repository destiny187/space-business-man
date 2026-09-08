# 아이템 미리보기·아이콘 배경 투명화

2026-09-08 사용자 요청: 강화 화면 캡처를 제공하고 아이템창의 어색한 이미지 바탕을 투명하게 바꾼다.

현재 실행판에서는 장비·보석 PNG에 단색 사각 배경이 남아 있었다. 공통 `FrontierEquipmentPreview`의 SubViewport에 투명 배경을 적용하고, 기존 INK 윤곽선 패스의 배경 픽셀 제외 옵션을 연결했다. 모델 재질의 크림색·검은 윤곽선·조명을 유지하면서 미리보기 뒤가 부모 UI에 자연스럽게 합성된다. 글자·버튼 가독성을 위한 메뉴 패널과 슬롯 테두리는 유지한다.

기존 Blender 모델을 Godot Forward+로 다시 렌더해 장비 아이콘 7개와 보석·가공 부품 PNG 22개의 배경을 투명하게 만들었다. SVG 아이콘은 기존 투명 벡터를 유지한다. 래스터 색상 지우기나 모델의 흰 도장을 투명하게 바꾸는 방식은 사용하지 않았다.

`render_equipment_icons.gd`에 전체 장비와 기존 자원 PNG를 각각 다시 출력하는 옵션 및 배경 알파 확인을 추가했다. 자원 PNG의 기존 해상도는 보존하고, 제품/광물 데이터의 모델과 기존 `retrofit_pack` 모델을 사용한다.

```sh
./tools/godot.sh --script res://scripts/showcase/render_equipment_icons.gd -- --all-equipment
./tools/godot.sh --script res://scripts/showcase/render_equipment_icons.gd -- --resources-only
./tools/godot.sh --headless --editor --import --quit
```

Godot 4.7.2 / Metal Forward+ 실제 창의 격리 저장 `/tmp/inventory-preview`에서 아이템·제작·신체·증강 화면을 확인했다. PNG 배경 알파 검사를 통과했고 새 오류 없이 캡처했다. 경제/성장 규칙·거래·모델 원본·음향은 변경하지 않았다. 이번 시각 변경에 전체 플레이 검사를 반복하지 않았다.

[증강 화면](media/transparent-inventory/augmentation.png) · [아이템창](media/transparent-inventory/inventory.png) · [제작](media/transparent-inventory/crafting.png) · [신체 열람](media/transparent-inventory/body.png) · [실제 창](media/transparent-inventory/live.txt) · [장비 렌더](media/transparent-inventory/equipment-render.txt) · [자원 렌더](media/transparent-inventory/resource-render.txt)
