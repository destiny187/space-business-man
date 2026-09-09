class_name FrontierAugmentationReadout
extends HBoxContainer
var app: FrontierCrewExpedition
var preview: FrontierEquipmentPreview
var appearance: FrontierSuitAppearance
var rows: Dictionary={}
var identity: Label
var tinted: int=-1
var equipment_stats: Label
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;name="신체"
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(250,180);preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(preview);preview.show_model(FrontierSuitAppearance.config().model)
	appearance=FrontierSuitAppearance.new();appearance.configure(preview.model);appearance.sync({})
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=300;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	identity=FrontierInterfaceStyle.label(column,"",22);identity.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	FrontierInterfaceStyle.label(column,"개인 신체 증강",14,FrontierInterfaceStyle.ACCENT)
	for key in FrontierCrewAugmentation.config().fields:
		var row:=HBoxContainer.new();column.add_child(row);var icon:=TextureRect.new();icon.texture=load("res://assets/ui/interface/augment_"+key+".svg");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(36,36);row.add_child(icon)
		var values:=VBoxContainer.new();values.add_theme_constant_override("separation",3);row.add_child(values)
		var label:=FrontierInterfaceStyle.label(values,"",15)
		var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(190,4);bar.show_percentage=false;values.add_child(bar);rows[key]={"label":label,"bar":bar}
	equipment_stats=FrontierInterfaceStyle.label(column,"",14);equipment_stats.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var visit:=Button.new();visit.text="증강 장치 위치";column.add_child(visit);visit.pressed.connect(func():app.stations.navigate("augmentation"))
	var note:=FrontierInterfaceStyle.label(column,"증강은 우주선의 장치에서 진행합니다.\n장비를 바꿔도 이 세계에서 유지됩니다.",13,FrontierInterfaceStyle.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or app.session.latest.is_empty():return
	var own: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	identity.text=own.profile.name
	equipment_stats.text="장비 / 숙련\n탐험복 Mk.%d  가방 %d칸\n채집 빈도 +%d%%  운송 숙련 %d단계"%[int(own.get("loadout",{}).get("suit_tier",1)),FrontierItemInventory.capacity(own),FrontierProgressionResearch.personal(own,"mining")*10,FrontierRovers.research(own)]
	if appearance.sync(own):preview.request_render()
	for key in rows:
		var level:=FrontierCrewAugmentation.level(own,key)
		var value:=FrontierCrewAugmentation.multiplier(own,key)
		var stat: String=FrontierCrewAugmentation.stat_text(own,key)
		rows[key].label.text="%s  %d단계\n%s"%[FrontierCrewAugmentation.config().fields[key].name,level,stat]
		rows[key].bar.max_value=FrontierCrewAugmentation.config().maximum_level;rows[key].bar.value=level
