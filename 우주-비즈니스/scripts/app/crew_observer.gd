class_name FrontierCrewObserver
extends Node
## Local-only camera. It never changes the guest actor, pilot, route or save.
var app: FrontierCrewExpedition
var active:=false
var release_pending:=false
var viewport: SubViewport
var view: FrontierCrewFlightView
var layer: CanvasLayer
var image: TextureRect
var caption: Label
var revision:=0

func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;process_priority=30

func toggle() -> void:
	if active:stop();return
	if app.session.hosting:
		app.feedback.show_cue("F8 관전은 참가 승무원이 사용할 수 있습니다.");return
	if not FrontierCrewObservation.available(app.session.latest,app.session.hosting):
		app.feedback.show_cue("호스트가 우주에서 비행 중일 때 관전할 수 있습니다.");return
	if app.arrival.active or app.any_menu_open():return
	app.cancel_placement()
	if view==null:_build()
	active=true;release_pending=true;app.mouse_steering=Vector2.ZERO
	app.local_direction=Vector2.ZERO;app.local_sprint=false
	app.session.send_input(Vector2.ZERO,-app.camera.global_basis.z,false,false,FrontierCrewObservation.neutral_input(),app.jump_request,false)
	app.ui.hide();layer.show();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.look_offset=Vector2.ZERO
	update_snapshot(app.session.latest)
	app.feedback.audio.play("sfx_pickup_resource")
	app._sync_mouse_capture()

func _build() -> void:
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(get_viewport().get_visible_rect().size)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	view=FrontierCrewFlightView.new();view.state={"manifest":app.session.manifest};view.observation_mode=true;view.exterior=true;view.scan_enabled=false
	viewport.add_child(view)
	layer=CanvasLayer.new();layer.layer=8;add_child(layer)
	image=TextureRect.new();image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.texture=viewport.get_texture();layer.add_child(image)
	caption=Label.new();caption.theme=app.ui_theme;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,10))
	layer.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);caption.offset_left=-255;caption.offset_right=255;caption.offset_top=-70;caption.offset_bottom=-24
	get_viewport().size_changed.connect(func():viewport.size=Vector2i(get_viewport().get_visible_rect().size))
	layer.hide()

func update_snapshot(value: Dictionary) -> void:
	if not active:return
	if not FrontierCrewObservation.available(value,app.session.hosting):stop("호스트 비행이 끝나 원래 시점으로 돌아왔습니다.");return
	var descriptor: Dictionary=value.host_view
	view.freight_carrier="shuttle:"+str(descriptor.actor) if descriptor.shuttle else "crew"
	view.freight_pilot=false;view.combat_actor=""
	view.combat_snapshot=value.crew.get("space_combat",{})
	view.update_terraforming(value.get("orbital_terraform",{}))
	view.refits.flight_mode=true;view.refits.update_loadout({"hull":"finch"} if descriptor.shuttle else value.get("vessel",{}))
	view.update_navigation(descriptor.navigation)
	caption.text="%s 관전   마우스 둘러보기   휠 거리   F8 돌아가기" % str(descriptor.name)
	revision+=1

func stop(message: String="") -> void:
	if not active:return
	active=false;release_pending=true;app.mouse_steering=Vector2.ZERO;app.mouse_resume_guard=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;layer.hide();app.ui.show()
	if app.space_view!=null:app.space_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if app.surface_world==null or app.arrival.active else SubViewport.UPDATE_DISABLED
	if not message.is_empty():app.feedback.show_cue(message)
	app.feedback.audio.play("sfx_pickup_resource")

func look(motion: Vector2) -> void:
	view.look_offset.x=wrapf(view.look_offset.x-motion.x,-PI,PI)
	view.look_offset.y=clampf(view.look_offset.y-motion.y,deg_to_rad(-78),deg_to_rad(78))

func zoom(direction: float) -> void:
	view.observation_distance=clampf(view.observation_distance+direction*8,24,160)

func input_blocked() -> bool:return active or release_pending

func _process(_delta: float) -> void:
	if release_pending and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var held:=false
		for key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E,KEY_SHIFT,KEY_SPACE,KEY_ALT,KEY_1,KEY_2,KEY_F]:
			if Input.is_physical_key_pressed(key):held=true;break
		if not held:release_pending=false
	if not active:return
	if not app.session.active or app.arrival.active or not FrontierCrewObservation.available(app.session.latest,app.session.hosting):stop();return
	if app.space_view!=null:app.space_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	view.presentation_blocked=FrontierClientSettings.ensure(get_tree()).is_open() or FrontierCursorPolicy.modal_open(get_tree()) or not get_window().has_focus()
