class_name FrontierExpeditionResearchPanel
extends VBoxContainer
## Local placement is a preview. Consumption and completed apparatus require a host receipt.
var app: FrontierCrewExpedition
var mode: String="bench"
var preview: FrontierResearchPreview
var flow: FrontierResearchFlow
var selected: String=""
var phase: String="ready"
var phase_time:=0.0
var loaded:=false
var sending:=false
var pending_sequence:=0
var receipt_revision:=0
var last_receipt: Dictionary={}
var specimens: Dictionary={}
var slot: FrontierResearchSampleSlot
var quantity: SpinBox
var bag_row: HBoxContainer
var input_row: HBoxContainer
var cost_row: HBoxContainer
var stage_label: Label
var hint: Label
var message: Label
var action: Button
var speaker: AudioStreamPlayer
var process_sound: AudioStreamPlayer
var assembled_id: String=""
var cost_signature: String=""
func configure(owner_app: FrontierCrewExpedition,access_mode: String="bench") -> void:
	app=owner_app;mode=access_mode;name="탐사 연구" if mode!="factory" else "시험기 조립";size_flags_vertical=Control.SIZE_EXPAND_FILL;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	flow=FrontierResearchFlow.new();add_child(flow)
	if mode=="factory":flow.custom_minimum_size.y=84
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_theme_constant_override("separation",18);add_child(row)
	preview=FrontierResearchPreview.new();preview.custom_minimum_size=Vector2(270,230 if mode=="factory" else 260);preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(preview)
	var detail:=VBoxContainer.new();detail.custom_minimum_size.x=292;row.add_child(detail)
	if mode=="factory":detail.add_theme_constant_override("separation",6)
	FrontierInterfaceStyle.label(detail,"심부 정밀 채집",22)
	stage_label=FrontierInterfaceStyle.label(detail,"",14,FrontierInterfaceStyle.ACCENT)
	hint=FrontierInterfaceStyle.label(detail,"",14,FrontierInterfaceStyle.MUTED);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size=Vector2(292,32 if mode=="factory" else 48)
	bag_row=HBoxContainer.new();detail.add_child(bag_row)
	for id in FrontierExpeditionResearch.config().projects.deep_mining.sample_resources:
		var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(88,70);tile.picture=FrontierResourceIcons.texture(id);tile.cargo_payload={"research_sample":id};tile.tooltip_text=FrontierResourceIcons.names()[id];bag_row.add_child(tile);specimens[id]=tile;tile.pressed.connect(func():prepare(id))
	input_row=HBoxContainer.new();detail.add_child(input_row)
	slot=FrontierResearchSampleSlot.new();slot.custom_minimum_size=Vector2(88,74);input_row.add_child(slot);slot.specimen_dropped.connect(prepare);slot.pressed.connect(func():
		if busy():return
		loaded=false;phase="ready";refresh())
	quantity=SpinBox.new();quantity.min_value=1;quantity.max_value=int(FrontierExpeditionResearch.config().projects.deep_mining.analysis_samples);quantity.step=1;quantity.custom_minimum_size.x=88;input_row.add_child(quantity)
	quantity.value_changed.connect(func(_value: float):refresh())
	cost_row=HBoxContainer.new();detail.add_child(cost_row)
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail.add_child(spacer)
	action=Button.new();action.custom_minimum_size.y=40;detail.add_child(action);action.pressed.connect(submit)
	message=FrontierInterfaceStyle.label(detail,"",13);message.custom_minimum_size=Vector2(292,32 if mode=="factory" else 42);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speaker=AudioStreamPlayer.new();speaker.bus="UI";speaker.volume_db=-12;add_child(speaker)
	process_sound=AudioStreamPlayer.new();process_sound.bus="SFX";process_sound.volume_db=-27;add_child(process_sound)
	app.session.request_started.connect(requested);app.session.response_received.connect(responded)
	visibility_changed.connect(func():
		if not is_visible_in_tree():speaker.stop();process_sound.stop()
		else:refresh())
func project() -> Dictionary:return app.session.latest.get("expedition_research",{}).get("projects",{}).get("deep_mining",{})
func busy() -> bool:return sending or pending_sequence>0 or phase=="success" or receipt_revision>int(app.session.latest.get("crew",{}).get("revision",0))
func play(id: String) -> void:
	if not is_visible_in_tree() or app.feedback==null:return
	speaker.stream=app.feedback.audio.stream(id);speaker.play()
func reject(reason: String) -> void:
	phase="error";loaded=false;process_sound.stop();message.text=reason;play("sfx_build_invalid");refresh()
func prepare(id: String) -> void:
	if busy():return
	if not project().get("evidence",{}).has(id):reject("발견한 표본만 계측할 수 있습니다.");return
	selected=id
	if mode=="journal":refresh();return
	if project().stage!="discovered":return
	if int(app.session.latest.get("inventory",{}).get(id,0))<=0:reject("내 배낭에 이 표본이 없습니다.");return
	loaded=true;phase="prepared";message.text="분석 실행 시 선택한 표본을 소비합니다.";play("sfx_pickup_resource");refresh()
func open() -> void:
	if not busy():loaded=false;selected="";phase="ready";message.text=""
	refresh()
func requested(sequence: int,kind: String,_args: Dictionary) -> void:
	if sending and kind==("equipment_research_prototype" if mode=="factory" else "research_contribute"):pending_sequence=sequence
func responded(sequence: int,value: Dictionary) -> void:
	if pending_sequence==0 or sequence!=pending_sequence:return
	pending_sequence=0;last_receipt=value.duplicate(true);process_sound.stop()
	if not value.get("ok",false):reject(str(value.get("error","작업을 완료하지 못했습니다.")));return
	loaded=false;receipt_revision=int(value.revision);phase="success";phase_time=0
	assembled_id=str(value.get("research",{}).get("item_id",""))
	message.text="시험기 조립 완료 · I에서 장착 / 화물 보관" if mode=="factory" else ("분석 완료 · 시험기 조립 가능" if value.research.stage=="analyzed" else "표본 계측 완료")
	play("sfx_factory_complete");refresh()
func submit() -> void:
	if busy() or mode=="journal" or action.disabled:return
	var kind: String="research_contribute"
	var args: Dictionary={"station_id":"ship:research","project":"deep_mining","resource":selected,"amount":int(quantity.value),"expected_stage":"discovered"}
	if mode=="factory":
		kind="equipment_research_prototype";args={"project":"deep_mining","building_id":app.business_panel.context_id,"expected_stage":project().stage}
	sending=true;phase="waiting";phase_time=0;message.text="조립 결과 확인 중" if mode=="factory" else "표본 계측 · 결과 확인 중"
	process_sound.stream=app.feedback.audio.stream("sfx_robot_charge",true);process_sound.play();refresh()
	var sent:=app.session.send_request(kind,args);sending=false
	if not sent:pending_sequence=0;reject("연결 상태를 확인한 뒤 다시 실행하세요.")
func refresh() -> void:
	var data:=project()
	if data.is_empty() or preview==null:return
	var state: String=data.stage
	var count:=FrontierExpeditionResearch.sample_count(data)
	var required:=int(FrontierExpeditionResearch.config().projects.deep_mining.analysis_samples)
	var stock: Dictionary=app.session.latest.get("inventory",{})
	if state!="discovered":loaded=false
	flow.research_stage=state;flow.amount=count;flow.required=required;flow.phase=phase;preview.phase=phase
	var inspected: String=selected if data.evidence.has(selected) else (str(data.evidence.keys()[0]) if not data.evidence.is_empty() else "")
	preview.present(state,inspected if mode=="journal" or loaded or phase=="success" else "")
	stage_label.text={"unseen":"발견되지 않은 표본","discovered":"표본 계측 · %d / %d"%[count,required],"analyzed":"분석 완료 · 조립 대기","prototyped":"시험기 준비 · 현장 시험 대기"}[state]
	hint.text={"unseen":"지하에서 보석을 발견하면 단서가 연결됩니다.","discovered":"내 배낭의 표본을 연구대에 올려 계측합니다.","analyzed":"현장 제작소 Mk.2 · 내 부품으로 시험기 조립","prototyped":"T2 시험기 · 정식 Mk.3 설계는 현장 시험 후 개방"}[state]
	if mode=="journal":hint.text="원정대 공동 기록 · 표본 계측은 원정선 연구대에서"
	for id in specimens:
		var tile: FrontierItemTile=specimens[id];tile.visible=data.evidence.has(id) if mode=="journal" else int(stock.get(id,0))>0;tile.disabled=busy() or not data.evidence.has(id);tile.selected=id==selected;tile.amount=str(int(stock.get(id,0))) if mode!="journal" else ("발견" if data.evidence.has(id) else "?");tile.modulate=Color.WHITE if data.evidence.has(id) else Color(.3,.36,.4);tile.queue_redraw()
	bag_row.visible=mode!="factory" and state in ["unseen","discovered"]
	input_row.visible=mode=="bench" and state in ["unseen","discovered"]
	slot.disabled=busy();slot.picture=FrontierResourceIcons.texture(selected) if loaded else null;slot.amount="×%d"%int(quantity.value) if loaded else "표본 슬롯";slot.selected=loaded;slot.queue_redraw()
	quantity.max_value=maxi(1,mini(required-count,int(stock.get(selected,0))));quantity.editable=loaded and not busy()
	cost_row.visible=mode=="factory"
	var cost: Dictionary=FrontierEquipment.config().items.miner_probe.cost
	var signature: String=JSON.stringify(stock)
	if mode=="factory" and signature!=cost_signature:
		cost_signature=signature
		for child in cost_row.get_children():cost_row.remove_child(child);child.queue_free()
		for id in cost:
			var col:=VBoxContainer.new();cost_row.add_child(col);col.add_child(FrontierResourceIcons.view(id,40));FrontierInterfaceStyle.label(col,"%d / %d"%[int(stock.get(id,0)),int(cost[id])],13)
	action.visible=mode!="journal"
	action.disabled=busy() or (not loaded if mode=="bench" else state not in ["analyzed","prototyped"] or not FrontierExpeditionBusiness.affordable(stock,cost))
	action.text=("조립 완료" if mode=="factory" else "계측 완료") if phase=="success" else "결과 확인 중…" if busy() else ("시험기 조립 · 내 배낭 부품" if mode=="factory" else "표본 분석")
	if mode=="factory" and state in ["analyzed","prototyped"]:
		var context: Dictionary={"crew":app.session.latest.crew,"business":app.business_panel.ledger.duplicate(),"location":app.business_panel.body_id,"expedition_research":app.session.latest.expedition_research}
		context.business.bags={app.session.latest.self_id:stock}
		var reason:=FrontierExpeditionResearch.prototype_reason(context,app.session.latest.self_id,{"project":"deep_mining","building_id":app.business_panel.context_id,"expected_stage":state})
		if not reason.is_empty():
			action.disabled=true
			if phase!="success":hint.text=reason
	if mode=="bench" and state in ["analyzed","prototyped"]:action.hide()
	message.modulate=FrontierInterfaceStyle.WARNING if phase=="error" else FrontierInterfaceStyle.ACCENT
func _process(delta: float) -> void:
	if not app.session.active:
		pending_sequence=0;sending=false;receipt_revision=0;loaded=false;phase="ready";return
	phase_time+=delta
	if phase=="success" and phase_time>1.2 and int(app.session.latest.crew.revision)>=receipt_revision:phase="ready"
	if phase=="waiting" and phase_time>8:message.text="응답 대기 중 · 창을 닫아도 결과는 기록됩니다."
	if is_visible_in_tree():refresh()
