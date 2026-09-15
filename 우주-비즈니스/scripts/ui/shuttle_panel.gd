class_name FrontierShuttlePanel
extends VBoxContainer
signal deploy_requested(holder: String)
var choices: OptionButton
var deploy_button: Button
var stow_button: Button
var cost: FrontierResourceReadout
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
	panel.label(self,"FINCH  1인승 항성계 운송선",22)
	var scope:=panel.label(self,"1인승    화물 4칸    항성계 내부 운송")
	scope.tooltip_text="W/S 속도  마우스  A/D 선회  Q/E 롤  Shift 부스트  Space 제동  Alt+W/S 저속 전후진  F 상호작용. 성간 이동은 공동 원정선에 합류하세요."
	cost=FrontierResourceReadout.new();add_child(cost);cost.value=FrontierCatalog.cost_text(FrontierShuttles.config().cost)
	choices=OptionButton.new();add_child(choices)
	deploy_button=panel.button(self,"기체 선택 → 호출 위치 지정",func():
		if choices.selected>=0:deploy_requested.emit(str(choices.get_item_metadata(choices.selected))))
	stow_button=panel.button(self,"격납고로 회수",func():
		if choices.selected>=0:panel.command.emit("shuttle_stow",{"holder":str(choices.get_item_metadata(choices.selected))}))
	info=panel.label(self,"")
	progress=ProgressBar.new();progress.max_value=float(FrontierShuttles.config().seconds);add_child(progress)
	build_button=panel.button(self,"FINCH 조립 시작",func():panel.command.emit("shuttle_build",{"factory_id":panel.context_id}))
	dock_button=panel.button(self,"공동 원정선에 합류",func():panel.command.emit("shuttle_dock",{}))
	dock_button.tooltip_text="필요한 화물은 먼저 직접 내리세요. 남은 화물은 FINCH에 보존됩니다."
	var cargo_button:=panel.button(self,"화물 슬롯 열기",func():panel.station_action.emit("cargo"));cargo_button.icon=FrontierResourceIcons.menu_texture("stone")
func update_snapshot(value: Dictionary) -> void:
	var actor:=str(value.self_id);var ship: Dictionary=value.crew.get("shuttles",{}).get(actor,{})
	var available: Dictionary={}
	for id in value.crew.get("shuttles",{}):
		var craft: Dictionary=value.crew.shuttles[id]
		if craft.state=="docked" and (id==actor or craft.get("company",false)):available[id]="Lotus 공용 FINCH" if craft.get("company",false) else "내 FINCH"
	panel.choices(choices,available)
	var at_carrier: bool=panel.context_kind=="ship" and value.get("local_shuttle","").is_empty()
	choices.visible=at_carrier;deploy_button.visible=at_carrier;stow_button.visible=at_carrier
	deploy_button.disabled=available.is_empty()
	var selected: Dictionary=value.crew.get("shuttles",{}).get(str(choices.get_item_metadata(choices.selected)) if choices.selected>=0 else "",{})
	stow_button.disabled=not FrontierShuttles.deployed(selected,str(value.location))
	cost.visible=panel.context_kind=="factory"
	progress.visible=ship.get("state","")=="assembling";progress.value=float(ship.get("progress",0))
	build_button.visible=ship.is_empty() and panel.context_kind=="factory";build_button.disabled=panel.context_kind!="factory"
	dock_button.visible=not value.get("local_shuttle","").is_empty()
	info.text="가방에 부품을 준비하고 Mk.2 제작소에서 조립하세요." if ship.is_empty() else ("조립 중  제작소 전력이 필요합니다." if ship.state=="assembling" else ("출동 중  개인 화물 4칸  같은 항성계만 이동" if ship.state=="sortie" else "착륙선 단말에서 호출 위치를 지정하세요. 내려온 기체에 접근해 F로 출발합니다."))
	if ship.is_empty():
		for craft in value.crew.get("shuttles",{}).values():
			if craft.get("company",false) and craft.state=="docked":info.text="Lotus 공용 FINCH가 대기 중입니다. 기체를 선택하고 호출 위치를 지정하세요.";break
