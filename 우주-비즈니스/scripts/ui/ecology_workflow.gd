class_name FrontierEcologyWorkflow
extends VBoxContainer
var app: FrontierCrewExpedition
var stages: Array[Label]=[]
var note: Label
var samples: HFlowContainer
var sample_signature:=""
var at_station:=false
var visit: Button
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	var strip:=HBoxContainer.new();add_child(strip);move_child(strip,0)
	for title in ["관측","분석","서식지","이식"]:
		var step:=FrontierInterfaceStyle.label(strip,title,13);step.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stages.append(step)
	note=FrontierInterfaceStyle.label(self,"",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;move_child(note,1)
	visit=Button.new();visit.text="표본 연구대에서 작업";add_child(visit);visit.pressed.connect(func():app.stations.navigate("research",2))
	samples=HFlowContainer.new();add_child(samples);move_child(samples,2)
func refresh(near: bool) -> void:
	var entry: Dictionary=app.survey_journal.selected_entry
	visible=not entry.is_empty() and entry.kind=="biology"
	if not visible:return
	visit.visible=not at_station
	var ecology: Dictionary=app.session.surface.ecology
	var form:=FrontierEcologyCatalog.form(entry.row.form_id)
	var record: Dictionary=ecology.planets.get(app.session.latest.location,{})
	var plot: Dictionary=record.get("plot",{})
	var analyzed: bool=ecology.research.has(form.environment)
	var established:=not plot.is_empty()
	var introduced:=false
	for row in record.get("introductions",{}).values():
		if row.form_id==form.id:introduced=true
	var completed: Array=[true,analyzed,established,introduced]
	for i in stages.size():
		stages[i].text=("✓ " if completed[i] else "%d "%(i+1))+["관측","분석","서식지","이식"][i]
		stages[i].modulate=FrontierInterfaceStyle.ACCENT if completed[i] else FrontierInterfaceStyle.MUTED
	for control in app.research_actions:control.hide();control.disabled=not near
	app.form_options.hide();app.sample_options.hide()
	note.text="착륙선 연구실에서 분석할 수 있습니다." if not near else ""
	var action: Button
	var cost:=0
	if not analyzed:
		action=app.research_actions[0];cost=int(FrontierEcologyCatalog.config().analysis_rock_cost)
		action.text="기초 분석 · 광물 %d"%cost
	elif not established:
		action=app.research_actions[1];cost=int(FrontierEcologyCatalog.config().plot_rock_cost)
		action.text="서식지 시험 · 광물 %d"%cost
		var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
		var point:=FrontierCrewWorld.vector(member.position)
		var underground: bool=app.surface_world!=null and app.surface_world.terrain.field.height(point.x,point.z)-point.y>6
		var environment: String="cave" if underground else str(record.get("profile",{}).get("environment",""))
		if form.environment!=environment:action.disabled=true;note.text="이 행성의 기질과 맞지 않습니다."
	else:
		action=app.research_actions[2];action.text="선택 표본 이식";action.disabled=not near or introduced
		if introduced:note.text="이식 시험 중 · 생물량 %.1f%%"%float(plot.get("biomass",0))
		var refill: Button=app.research_actions[3]
		refill.visible=float(plot.get("support_remaining",0))<=float(FrontierEcologyCatalog.config().plot_support_seconds)-60
		refill.text="지원 팩 보충 · 광물 %d"%int(FrontierEcologyCatalog.config().plot_resupply_rock_cost)
		refill.disabled=not near or int(app.session.latest.crew.rock)<int(FrontierEcologyCatalog.config().plot_resupply_rock_cost)
	if action!=null:
		action.show()
		if cost>int(app.session.latest.crew.rock):action.disabled=true;note.text="착륙지 창고 · 실험용 광물 %d 필요"%cost
	var candidates: Dictionary={}
	for id in ecology.specimens:
		var sample: Dictionary=ecology.specimens[id]
		if sample.state=="cargo" and sample.form_id==form.id and sample.source_body!=app.session.latest.location:candidates[id]=sample
	samples.visible=established and not introduced
	var signature:=str(candidates)+str(app.sample_options.selected)
	if signature!=sample_signature:
		sample_signature=signature
		for child in samples.get_children():samples.remove_child(child);child.queue_free()
		for id in candidates:
			var tile:=Button.new();tile.text=form.name;tile.icon=FrontierResourceIcons.menu_texture(FrontierResourceIcons.specimen_id(form));samples.add_child(tile)
			tile.toggle_mode=true
			tile.button_pressed=app.sample_options.selected>=0 and app.sample_options.get_item_metadata(app.sample_options.selected)==id
			tile.pressed.connect(func():
				for i in app.sample_options.item_count:
					if app.sample_options.get_item_metadata(i)==id:app.sample_options.select(i);break)
	if established:
		var selected: String=str(app.sample_options.get_item_metadata(app.sample_options.selected)) if app.sample_options.selected>=0 else ""
		app.research_actions[2].disabled=app.research_actions[2].disabled or not candidates.has(selected)
		if candidates.is_empty() and not introduced:note.text="다른 행성에서 확보한 이 생물의 실물 표본이 필요합니다."
		elif not introduced:
			var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
			var point:=FrontierCrewWorld.vector(member.position)
			var layer: String="cave" if app.surface_world!=null and app.surface_world.terrain.field.height(point.x,point.z)-point.y>6 else "surface"
			var climate:=FrontierEcology.climate_at(record,point,layer)
			var reason:=FrontierEcology.unsuitable(form,climate,layer)
			if not climate.get("restored",false):reason="지원 중인 실험 구획 안에서 이식하세요."
			if not reason.is_empty():app.research_actions[2].disabled=true;note.text=reason

	if not at_station:
		for control in app.research_actions:control.hide()
		samples.hide();note.text="기록 열람 · 착륙선 표본 연구대"
	else:visit.hide()
