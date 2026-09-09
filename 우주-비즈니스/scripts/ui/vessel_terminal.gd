class_name FrontierVesselTerminal
extends HBoxContainer
var panel: FrontierBusinessPanel
var preview: FrontierEquipmentPreview
var heading: Label
var owner_label: Label
var capacity: ProgressBar
var capacity_label: Label
var cards: Dictionary={}
static func model_path(hull_id: String) -> String:
	if hull_id in ["kestrel","finch"]:return "ships/"+hull_id
	return str(FrontierSpaceStation.config().hulls.get(hull_id,{}).get("model","res://assets/models/ships/kestrel.glb")).trim_prefix("res://assets/models/").trim_suffix(".glb")
func configure(owner_panel: FrontierBusinessPanel) -> void:
	panel=owner_panel;add_theme_constant_override("separation",24)
	var hull:=VBoxContainer.new();hull.custom_minimum_size.x=230;add_child(hull)
	heading=FrontierInterfaceStyle.label(hull,"KESTREL",25)
	owner_label=FrontierInterfaceStyle.label(hull,"공동 원정선",14,FrontierInterfaceStyle.MUTED)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(230,220);hull.add_child(preview)
	capacity_label=FrontierInterfaceStyle.label(hull,"화물",14)
	capacity=ProgressBar.new();capacity.show_percentage=false;capacity.custom_minimum_size.y=6;hull.add_child(capacity)
	var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);add_child(grid)
	for row in [["lotus","Lotus 보급","기초 물자  현장 투하","ice"],["augmentation","신체 증강","선내 장치  강화","reinforced_frame"],["cargo","화물창","배낭 ↔ 선박","stone"],["inventory","내 아이템","장비  번호 슬롯","reinforced_frame"],["research","연구","설계도  생태 분석","crystal"],["shipyard","정비","선체  모듈","control_circuit"],["launch","탑승  이륙","승무원 탑승 후 출항","ship_module"],["rejoin","원정선 합류","화물은 먼저 직접 하역","ship_module"]]:
		var button:=Button.new();button.custom_minimum_size=Vector2(180,100);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(button)
		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=16;content.offset_top=12;content.offset_right=-16
		var top:=HBoxContainer.new();top.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(top)
		var icon:=FrontierResourceIcons.view(row[3],30);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;top.add_child(icon)
		FrontierInterfaceStyle.label(top,row[1],18).mouse_filter=Control.MOUSE_FILTER_IGNORE
		var hint:=FrontierInterfaceStyle.label(content,row[2],12,FrontierInterfaceStyle.MUTED);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.set_meta("hint",hint)
		button.tooltip_text=row[1]+"  "+row[2]
		button.pressed.connect(func():
			if row[0]=="rejoin":panel.command.emit("shuttle_dock",{})
			else:panel.station_action.emit(row[0]))
		cards[row[0]]=button
func update_snapshot(value: Dictionary) -> void:
	var personal: bool=not value.get("local_shuttle","").is_empty()
	var hull_id: String="finch" if personal else str(value.get("vessel",{}).get("hull","kestrel"))
	if preview.model_path!=model_path(hull_id):
		preview.show_model(model_path(hull_id));preview.camera.size*=.72
	heading.text="FINCH" if personal else hull_id.to_upper()
	if panel.context_kind=="ship":panel.heading.text=heading.text+"  선박 관리  Esc 닫기"
	owner_label.text=(str(value.crew.members[value.self_id].profile.name)+"  개인 운송선") if personal else "공동 원정선  승무원 공유"
	var site:=FrontierItemInventory.ship_site(value.crew)
	var slots:=int(FrontierShuttles.config().cargo_slots) if personal else FrontierItemInventory.warehouse_capacity(site)
	var used:=FrontierItemInventory.warehouse_used(site)
	capacity.max_value=slots;capacity.value=used;capacity_label.text="화물  %d / %d칸"%[used,slots]
	for id in ["research","shipyard","augmentation"]:cards[id].visible=not personal
	cards.rejoin.visible=personal
	cards.launch.get_meta("hint").text="혼자 탑승하여 출발" if personal else "승무원 탑승 후 출항"
	cards.launch.tooltip_text="소형선으로 이륙" if personal else "출동 중인 소형선이 복귀하고 전원 탑승하면 이륙합니다."
