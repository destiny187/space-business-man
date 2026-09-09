class_name FrontierLotusSupportController
extends Node
var app: FrontierCrewExpedition
var panel: PanelContainer
var preview: FrontierEquipmentPreview
var info: Label
var status: Label
var request_button: Button
var rows: VBoxContainer
var hint: Label
var marker: Label
var selected: String="iron"
var buttons: Dictionary={}
var visuals: Dictionary={}
var remote_colliders: Dictionary={}
var surface_parent: Node3D
var pending:=-1
var list_signature:=""
var own_audio: FrontierAudio
var hovered:=""
var detail_cache: Dictionary={}
var detail_frame:=-1
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	own_audio=FrontierAudio.new();add_child(own_audio)
	panel=PanelContainer.new();app.ui.add_child(panel);panel.theme=FrontierInterfaceStyle.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.offset_left=30;panel.offset_right=-30;panel.offset_top=40;panel.offset_bottom=-110
	panel.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,20))
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);panel.add_child(box)
	var header:=HBoxContainer.new();box.add_child(header)
	var title:=FrontierInterfaceStyle.label(header,"LOTUS  개척 지원",25);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="닫기  Esc";header.add_child(close);close.pressed.connect(panel.hide)
	var content:=HBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",22);box.add_child(content)
	var art:=VBoxContainer.new();content.add_child(art)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(250,180);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;art.add_child(preview);preview.show_model("lotus/heron")
	preview.camera.keep_aspect=Camera3D.KEEP_WIDTH
	FrontierInterfaceStyle.label(art,"HERON  현장 보급선",18)
	var summary:=FrontierInterfaceStyle.label(art,"신청 위치 주변에 상자를 투하합니다.\n떠나 있어도 물자는 현장에 남습니다.",13);summary.custom_minimum_size.x=250;summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_child(right)
	var selection:=HBoxContainer.new();selection.add_theme_constant_override("separation",8);right.add_child(selection)
	var amount:=int(FrontierLotusSupport.config().package_amount)
	for resource in FrontierLotusSupport.config().prices:
		var tile:=Button.new();tile.toggle_mode=true;tile.custom_minimum_size=Vector2(88,95);tile.icon=FrontierResourceIcons.menu_texture(resource);tile.expand_icon=true;tile.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;tile.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;tile.add_theme_constant_override("icon_max_width",58);tile.text=FrontierCatalog.entry("resources",resource).name+"  "+str(amount);tile.tooltip_text="이 재료 %d개가 든 상자 한 개를 요청합니다."%amount;selection.add_child(tile);buttons[resource]=tile
		var id: String=resource
		tile.pressed.connect(func():selected=id;refresh())
	info=FrontierInterfaceStyle.label(right,"",15)
	status=FrontierInterfaceStyle.label(right,"선박 통신으로 보급을 요청합니다.",14);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=360
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	request_button=Button.new();request_button.custom_minimum_size.y=46;box.add_child(request_button);request_button.pressed.connect(request_supply)
	panel.hide()
	hint=FrontierInterfaceStyle.label(app.ui,"",18);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.hide()
	marker=FrontierInterfaceStyle.label(app.ui,"",14,FrontierInterfaceStyle.ACCENT);marker.add_theme_color_override("font_shadow_color",Color.BLACK);marker.add_theme_constant_override("shadow_outline_size",5);marker.mouse_filter=Control.MOUSE_FILTER_IGNORE;marker.hide()
	app.session.response_received.connect(response)
func near_terminal() -> bool:
	if app.surface_world==null or app.session.latest.is_empty():return false
	var member: Dictionary=app.session.latest.crew.members.get(app.session.latest.self_id,{})
	return not member.get("aboard",true) and FrontierCrewWorld.vector(member.get("position",[9999,0,0])).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
func toggle() -> void:
	if not near_terminal():return
	if app.session.latest.get("phase","")!="playing":return
	if panel.visible:panel.hide();return
	app.open_menu(panel);refresh()
func request_supply() -> void:
	if pending>=0:return
	status.text="Lotus에 요청 전송 중…"
	pending=app.session.next_sequence
	request_button.disabled=true
	if not app.session.send_request("lotus_request",{"resource":selected}):pending=-1;refresh()
func response(sequence: int,result: Dictionary) -> void:
	if sequence!=pending:return
	pending=-1
	if result.get("ok",false):
		status.text="접수 완료  상자 위치는 현장 표식으로 확인하세요."
		own_audio.play("ui_lotus_dispatch")
	else:
		status.text=str(result.get("error","보급 요청 실패"));app.feedback.audio.play("sfx_build_invalid")
	refresh()
func refresh() -> void:
	if app.session.latest.is_empty():return
	var state: Dictionary=app.session.latest.get("lotus",{})
	for id in buttons:buttons[id].button_pressed=id==selected
	var free:=int(state.get("free_remaining",0));var cooldown:=int(ceil(float(state.get("cooldown",0))))
	var amount:=int(FrontierLotusSupport.config().package_amount)
	var fee:=0 if free>0 else int(FrontierLotusSupport.config().prices[selected])*amount
	info.text="무료 지원 %d회   공동 자금 %d Cr"%[free,int(state.get("credits",0))]
	var cost: String="무료 지원" if fee==0 else "%d Cr"%fee
	request_button.text="%s %d개 요청  /  %s"%[FrontierCatalog.entry("resources",selected).name,amount,cost]
	if cooldown>0:request_button.text="보급선 출동 대기  %d초"%cooldown
	var member: Dictionary=app.session.latest.crew.members.get(app.session.latest.self_id,{})
	request_button.disabled=pending>=0 or cooldown>0 or app.surface_world==null or member.get("aboard",true) or int(state.get("credits",0))<fee
	var signature:=JSON.stringify(state.get("crates",{}))
	if signature==list_signature:return
	list_signature=signature
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
	for row in state.get("crates",{}).values():
		var card:=HBoxContainer.new();rows.add_child(card)
		var icon:=TextureRect.new();icon.texture=FrontierResourceIcons.menu_texture(row.resource);icon.custom_minimum_size=Vector2(36,36);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card.add_child(icon)
		var text:=FrontierInterfaceStyle.label(card,"%s  %d개\n%s"%[FrontierCatalog.entry("resources",row.resource).name,int(row.remaining),FrontierLotusSupport.phase(row)],13);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func _process(delta: float) -> void:
	if not app.session.active or app.session.latest.get("phase","")!="playing":hint.hide();marker.hide();return
	if app.session.hosting:app.session.authority.lotus_clearance_provider=clearance
	var size:=app.get_viewport().get_visible_rect().size
	if panel.visible:
		if not near_terminal():panel.hide()
		else:refresh()
	sync_visuals(delta)
	update_hint()
func sync_visuals(delta: float) -> void:
	var parent: Node3D=app.surface_world
	if parent!=surface_parent or not is_instance_valid(surface_parent):
		for node in visuals.values():
			if is_instance_valid(node):node.queue_free()
		visuals.clear();surface_parent=parent
	var state: Dictionary=app.session.latest.get("lotus",{}).get("crates",{})
	var point:=Vector3.ZERO
	if app.actors.has(app.session.latest.self_id):point=app.actors[app.session.latest.self_id].position
	for id in visuals.keys():
		if not state.has(id):visuals[id].queue_free();visuals.erase(id)
	if parent!=null:
		for id in state:
			if not visuals.has(id):
				var model:=FrontierLotusDelivery.new();parent.add_child(model);visuals[id]=model
			var model: FrontierLotusDelivery=visuals[id]
			model.blocked=app.feedback.blocked() or app.arrival.active or app.outside
			model.accept(state[id]);model.present(delta,model.blocked,point)
	# Occupied remote planets need collision only, never duplicate rendering/audio.
	if app.session.hosting:
		var world: Dictionary=app.session.authority.world
		var wanted: Dictionary={}
		for row in world.get("lotus",{}).get("crates",{}).values():
			var key: String="surface:"+row.body_id
			if not row.landed or not app.spaces.spaces.has(key):continue
			wanted[row.id]=true
			var root: Node3D=app.spaces.spaces[key].root
			if not is_instance_valid(remote_colliders.get(row.id)) or remote_colliders[row.id].get_parent()!=root:
				if is_instance_valid(remote_colliders.get(row.id)):remote_colliders[row.id].queue_free()
				remote_colliders[row.id]=FrontierLotusDelivery.make_collision(root)
			remote_colliders[row.id].position=FrontierCrewWorld.vector(row.position);remote_colliders[row.id].rotation.y=float(row.heading)+PI
		for id in remote_colliders.keys():
			if not wanted.has(id):
				if is_instance_valid(remote_colliders[id]):remote_colliders[id].queue_free()
				remote_colliders.erase(id)
func update_hint() -> void:
	hovered="";hint.hide();marker.hide()
	if app.surface_world==null or not app._mouse_look_allowed() or app.arrival.active:return
	var actor: Node3D=app.actors.get(app.session.latest.self_id)
	if actor==null:return
	var state: Dictionary=app.session.latest.get("lotus",{}).get("crates",{})
	var nearest: Dictionary={};var best:=INF
	for row in state.values():
		if int(row.remaining)==0:continue
		var p:=FrontierCrewWorld.vector(row.position)+Vector3.UP
		var distance:=actor.position.distance_to(p)
		if distance<best:nearest=row;best=distance
		if not row.landed or distance>float(FrontierLotusSupport.config().interaction_distance):continue
		if (-app.camera.global_basis.z).dot((p-app.camera.global_position).normalized())<.82:continue
		var query:=PhysicsRayQueryParameters3D.create(app.camera.global_position,p);query.exclude=[actor.get_rid()]
		var hit:=app.camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not hit.collider.has_meta("lotus_crate"):continue
		hovered=row.id
		hint.text="F  보급 수령  %s %d개"%[FrontierCatalog.entry("resources",row.resource).name,int(row.remaining)]
		hint.size=Vector2(480,36);hint.position=Vector2((get_viewport().get_visible_rect().size.x-480)/2,get_viewport().get_visible_rect().size.y*.64);hint.show()
	if not nearest.is_empty():
		marker.text="◇ LOTUS  %dm  %s"%[int(best),"보급 상자" if nearest.landed else "투하 예정"]
		var target:=FrontierCrewWorld.vector(nearest.position)+Vector3.UP*2.8
		var screen:=app.camera.unproject_position(target)
		var size:=get_viewport().get_visible_rect().size
		if app.camera.is_position_behind(target):screen=Vector2(size.x*.5,size.y-150)
		marker.position=Vector2(clampf(screen.x-100,20,size.x-250),clampf(screen.y,100,size.y-155));marker.show()
func interact() -> bool:
	if hovered.is_empty():return false
	app.session.send_request("lotus_collect",{"crate_id":hovered});return true
func clearance(body_id: String,p: Vector3,radius: float) -> bool:
	if not app.session.hosting:return false
	var root: Node3D=app.spaces.root_for_body(body_id)
	var terrain:=app.spaces.terrain_for_body(body_id)
	if terrain==null:return true # Domain checks persist when nobody occupies this planet.
	if app.surface_world!=null and app.surface_world.body.id==body_id and app.surface_world.water_depth(p)>.05:return false
	if app.surface_world!=null and app.surface_world.body.id==body_id:
		var details: FrontierSurfaceDetails=app.surface_world.surface_details
		if details!=null and not details.meshes.is_empty():
			if detail_frame!=Engine.get_process_frames():detail_cache.clear();detail_frame=Engine.get_process_frames()
			var span: float=details.settings.tile_size
			for x in range(floori((p.x-radius-3)/span),floori((p.x+radius+3)/span)+1):
				for z in range(floori((p.z-radius-3)/span),floori((p.z+radius+3)/span)+1):
					var key:=Vector2i(x,z)
					if not detail_cache.has(key):detail_cache[key]=details.candidates(key)
					for item in detail_cache[key]:
						var bounds: AABB=item.transform*details.meshes[int(item.variant)%details.meshes.size()].get_aabb()
						if bounds.grow(radius).has_point(p+Vector3.UP*.5):return false
	var query:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new();box.size=Vector3(radius*2,4,radius*2);query.shape=box;query.transform.origin=p+Vector3.UP*2.2;query.collision_mask=1
	for hit in root.get_world_3d().direct_space_state.intersect_shape(query,32):
		if not hit.collider.has_meta("lotus_crate"):return false
	return true
