class_name FrontierAugmentationReadout
extends HBoxContainer
var app: FrontierCrewExpedition
var preview: FrontierEquipmentPreview
var rows: Dictionary={}
var identity: Label
var tinted: int=-1
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;name="신체"
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(250,180);preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(preview);preview.show_model("crew/surveyor_suit")
	var column:=VBoxContainer.new();column.custom_minimum_size.x=240;column.size_flags_vertical=Control.SIZE_SHRINK_CENTER;add_child(column)
	identity=FrontierInterfaceStyle.label(column,"",22);identity.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	FrontierInterfaceStyle.label(column,"개인 신체 증강",14,FrontierInterfaceStyle.ACCENT)
	for key in FrontierCrewAugmentation.config().fields:
		var row:=HBoxContainer.new();column.add_child(row);row.add_child(FrontierResourceIcons.view(FrontierCrewAugmentation.config().fields[key].gem,32))
		var values:=VBoxContainer.new();values.add_theme_constant_override("separation",3);row.add_child(values)
		var label:=FrontierInterfaceStyle.label(values,"",15)
		var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(190,4);bar.show_percentage=false;values.add_child(bar);rows[key]={"label":label,"bar":bar}
	var note:=FrontierInterfaceStyle.label(column,"증강은 우주선의 장치에서 진행합니다.\n장비를 바꿔도 이 세계에서 유지됩니다.",13,FrontierInterfaceStyle.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or app.session.latest.is_empty():return
	var own: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	identity.text=own.profile.name
	if tinted!=int(own.profile.tint):tinted=int(own.profile.tint);app._suit_color(preview.model,tinted)
	for key in rows:
		var level:=FrontierCrewAugmentation.level(own,key)
		var value:=FrontierCrewAugmentation.multiplier(own,key)
		var stat: String=("이동 %.1f m/s"%(value*float(FrontierCrewSurface.config().movement_speed))) if key=="mobility" else (("피해 %.0f%%"%(value*100)) if key=="combat" else ("최대 체력 %.0f"%FrontierCrewAugmentation.maximum_health(own)))
		rows[key].label.text="%s · %d단계\n%s"%[FrontierCrewAugmentation.config().fields[key].name,level,stat]
		rows[key].bar.max_value=FrontierCrewAugmentation.config().maximum_level;rows[key].bar.value=level
