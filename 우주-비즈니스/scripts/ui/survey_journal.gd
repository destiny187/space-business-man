class_name FrontierSurveyJournal
extends VBoxContainer
var app: FrontierCrewExpedition
var grid: GridContainer
var details: VBoxContainer
var last_signature:=""
var preview: FrontierEquipmentPreview
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	FrontierInterfaceStyle.label(self,"조사한 대상 · 최대 24개",14)
	grid=GridContainer.new();grid.columns=4;add_child(grid)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(300,120);add_child(preview);preview.hide()
	details=VBoxContainer.new();add_child(details)
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or app.session.latest.is_empty() or app.session.surface.is_empty():return
	var records: Dictionary=app.session.latest.crew.get("survey",{})
	var observations: Dictionary=app.session.surface.ecology.observations
	var signature:=JSON.stringify(records)+JSON.stringify(observations)
	if signature==last_signature:return
	last_signature=signature
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var entries: Array=[]
	for row in records.values():
		entries.append({"kind":"mineral","row":row,"name":FrontierCatalog.entry("resources",row.resource).name,"icon":row.resource})
	for row in observations.values():
		var form:=FrontierEcologyCatalog.form(row.form_id)
		entries.append({"kind":"biology","row":row,"name":form.name,"icon":FrontierResourceIcons.specimen_id(form)})
	for entry in entries.slice(maxi(0,entries.size()-24)):
		var tile:=Button.new();tile.icon=FrontierResourceIcons.texture(entry.icon);tile.expand_icon=true;tile.custom_minimum_size=Vector2(70,60);tile.tooltip_text=entry.name;grid.add_child(tile);tile.pressed.connect(func():select(entry))
	if entries.is_empty():FrontierInterfaceStyle.label(grid,"E 유지로 생물·광물을 조사하세요.",12)
	else:select(entries.back())
func select(entry: Dictionary) -> void:
	for child in details.get_children():details.remove_child(child);child.queue_free()
	FrontierInterfaceStyle.label(details,entry.name,16)
	preview.visible=entry.kind=="biology"
	if entry.kind=="biology":
		for index in app.form_options.item_count:
			if app.form_options.get_item_metadata(index)==entry.row.form_id:app.form_options.select(index);break
		var form:=FrontierEcologyCatalog.form(entry.row.form_id)
		var model_path: String="bestiary/"+str(form.lods.near.path).get_file().trim_suffix(".glb")
		if preview.model_path!=model_path:preview.show_model(model_path);preview.camera.size*=.7
		preview.tooltip_text="드래그하여 생물 형태 회전"
		var info:=FrontierSurfaceSurvey.biology_info(form)
		for note in info.notes:
			var label:=FrontierInterfaceStyle.label(details,note.text,12);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var condition:=FrontierInterfaceStyle.label(details,info.condition,12,FrontierInterfaceStyle.ACCENT);condition.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		FrontierInterfaceStyle.label(details,"자유 정원 배치·배양은 후속 개발 예정",12,FrontierInterfaceStyle.MUTED)
	else:FrontierInterfaceStyle.label(details,"채집기 %d등급 · 매장량은 현장에서 재조사"%int(entry.row.tier),12)
	var source:=FrontierUniverse.body_from_id(app.session.manifest,entry.row.body_id)
	FrontierInterfaceStyle.label(details,"발견 행성 · "+str(source.get("name",entry.row.body_id)),12,FrontierInterfaceStyle.MUTED)
