class_name FrontierShuttlePanel
extends VBoxContainer
var panel: FrontierBusinessPanel
var app: FrontierCrewExpedition
var info: Label
var progress: ProgressBar
var build_button: Button
var dock_button: Button
var preview: FrontierEquipmentPreview
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel;name="소형선"
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(270,200);preview.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;add_child(preview);preview.show_model("ships/finch");preview.camera.size*=.7
	panel.label(self,"FINCH · 1인승 항성계 운송선",22)
	panel.label(self,"W/S 추진 · 마우스 조종 · Shift 가속 · Tab 행성 선택 · F 착륙\n다른 행성에서 직접 채집·창고 인수 후 귀환합니다. 성간 이동은 원정선에 합류하세요.")
	var cost:=FrontierResourceReadout.new();add_child(cost);cost.value=FrontierCatalog.cost_text(FrontierShuttles.config().cost)
	info=panel.label(self,"")
	progress=ProgressBar.new();progress.max_value=float(FrontierShuttles.config().seconds);add_child(progress)
	build_button=panel.button(self,"가방 부품으로 조립 · Mk.2 제작소",func():panel.command.emit("shuttle_build",{"factory_id":panel.context_id}))
	dock_button=panel.button(self,"공동 원정선에 합류 · 소형선 화물 유지",func():panel.command.emit("shuttle_dock",{}))
	panel.button(self,"운송 창고 열기",func():panel.station_action.emit("cargo"))
func update_snapshot(value: Dictionary) -> void:
	var actor:=str(value.self_id);var ship: Dictionary=value.crew.get("shuttles",{}).get(actor,{})
	progress.visible=ship.get("state","")=="assembling";progress.value=float(ship.get("progress",0))
	build_button.visible=ship.is_empty();build_button.disabled=panel.context_kind!="factory"
	dock_button.visible=not value.get("local_shuttle","").is_empty()
	info.text="가방에 부품을 준비하고 Mk.2 제작소에서 조립하세요." if ship.is_empty() else ("조립 중 · 제작소 전력이 필요합니다." if ship.state=="assembling" else ("출동 중 · 개인 화물 4칸 · 같은 항성계만 이동" if ship.state=="sortie" else "착륙선 옆 FINCH에 접근해 F로 출발하세요."))
