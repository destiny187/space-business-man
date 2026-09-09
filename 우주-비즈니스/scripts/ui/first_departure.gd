class_name FrontierFirstDeparture
extends Control
## Optional local teaching only. Every action uses the normal navigation/host path.
var app: FrontierCrewExpedition
var letter: ColorRect
var checked_world := ""
var welcome_seen := ConfigFile.new()
var welcome_path := "user://welcome_letters.cfg"
var depart: Button
var seen := ConfigFile.new()
var path: String
var player_key := ""
var new_player := false
var progress: Dictionary = {}
var card: PanelContainer
var title: Label
var detail: Label
var counter: Label
var icon: TextureRect
var highlight := Rect2()
var step := ""
var initial_system := -1
var clock := 0.0

func configure(owner_app: FrontierCrewExpedition) -> void:
	app = owner_app
	theme = FrontierInterfaceStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	path = app.profile.path.get_base_dir() + "/play_guide.cfg"
	seen.load(path)
	var profile_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(app.profile.path)) if FileAccess.file_exists(app.profile.path) else null
	new_player = not profile_data is Dictionary or profile_data.get("sessions", {}).is_empty()
	if app.test_mode:welcome_path = app.profile.path.get_base_dir() + "/welcome_letters.cfg"
	welcome_seen.load(welcome_path)
	letter=ColorRect.new();letter.color=Color(.015,.035,.055,.72);letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(letter);letter.hide()
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);letter.add_child(center)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(minf(570,app.get_viewport().get_visible_rect().size.x-40),0);center.add_child(panel)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("e9e3d3");paper.border_color=Color("689b9d");paper.set_border_width_all(2);paper.set_corner_radius_all(8);paper.set_content_margin_all(30);panel.add_theme_stylebox_override("panel",paper)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",20);panel.add_child(box)
	var stamp:=Label.new();stamp.text="LOTUS 개척사업부  /  지구 발신";stamp.add_theme_color_override("font_color",Color("376569"));stamp.add_theme_font_size_override("font_size",16);box.add_child(stamp)
	var letter_title:=Label.new();letter_title.text="첫 개척 임무에 오신 것을 환영합니다.";letter_title.add_theme_color_override("font_color",Color("203b43"));letter_title.add_theme_font_size_override("font_size",25);box.add_child(letter_title)
	var text:=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x=panel.custom_minimum_size.x-60;text.text="안녕하세요, 개척자님.\nLotus와 함께 새로운 테라포밍 현장을 찾아보세요.\n\n먼저 태양계를 천천히 둘러보세요.\n태양계는 보호 대상이라 착륙 / 테라포밍할 수 없습니다.\n마우스로 시선을 돌리고 W/S로 비행할 수 있어요.\n행성을 잠시 바라보면 스캔 결과가 나타납니다.\n\n준비가 되면 우주 화면의 청록색 항성계 표식을 찾아보세요.\n표식을 조준하고 F 또는 왼쪽 클릭으로 이동할 수 있어요.\n재료가 부족하면 선박에 접근해 F → Lotus 보급을 여세요.\n착륙선 옆 공용 FINCH는 F로 탑승할 수 있습니다.\n\n— Lotus 개척 지원팀";text.add_theme_color_override("font_color",Color("30474c"));text.add_theme_font_size_override("font_size",18);box.add_child(text)
	var close:=Button.new();close.text="편지 접기  태양계 둘러보기";close.custom_minimum_size.y=46;box.add_child(close)
	close.pressed.connect(func():
		welcome_seen.set_value("read",checked_world,true);welcome_seen.save(welcome_path);letter.hide();app.cursor_released=false;app.get_viewport().gui_release_focus())
	letter.z_index = 10
	depart = Button.new()
	depart.text = "G  은하 지도"
	depart.custom_minimum_size = Vector2(180, 32)
	depart.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	depart.offset_left = -208
	depart.offset_right = -28
	depart.offset_top = 218
	depart.offset_bottom = 250
	add_child(depart)
	depart.pressed.connect(func():app.navigation_ui.open_galaxy())
	depart.hide()
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", FrontierInterfaceStyle.box(Color("10191feb"), FrontierInterfaceStyle.ACCENT, 16))
	add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	icon = TextureRect.new()
	icon.texture = load("res://assets/ui/interface/ship.svg")
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	counter = FrontierInterfaceStyle.label(column, "", 11, FrontierInterfaceStyle.ACCENT)
	title = FrontierInterfaceStyle.label(column, "", 18)
	detail = FrontierInterfaceStyle.label(column, "", 13)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = 250
	var footer := FrontierInterfaceStyle.label(column, "Esc → 설정 → 조작  소리에서 끄기", 10, FrontierInterfaceStyle.MUTED)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.hide()
	app.session.response_received.connect(_response)

func update_snapshot(value: Dictionary) -> void:
	var welcome_key: String = value.galaxy_id + ":" + value.self_id
	if checked_world != welcome_key:
		checked_world = welcome_key
		if int(value.crew.navigation.system) == 0 and value.crew.get("landing", {}).is_empty() and not bool(welcome_seen.get_value("read", welcome_key, false)):
			letter.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var key: String = value.self_id
	if player_key != key:
		player_key = key
		progress = seen.get_value("players", key, {"eligible":new_player, "travel":false, "inventory":false, "complete":false})
		_save()
	var nav: Dictionary = value.crew.navigation
	if initial_system < 0:initial_system = int(nav.system)
	if nav.mode != "jump" and int(nav.system) != initial_system and not progress.get("travel", false):
		progress.travel = true
		_save()

func _save() -> void:
	if player_key.is_empty():return
	seen.set_value("players", player_key, progress)
	if seen.save(path) != OK:push_warning("플레이 가이드 진행 저장 실패")

func enabled() -> bool:
	var settings := FrontierClientSettings.current(get_tree())
	var mode: int = int(settings.values.get("tutorial_mode", 0)) if settings != null else 0
	return mode == 1 or (mode == 0 and progress.get("eligible", false) and not progress.get("complete", false))

func can_open_map() -> bool:
	if app.session.latest.is_empty() or not app.session.active:return false
	var value: Dictionary = app.session.latest
	return value.get("phase") == "playing" and value.crew.get("landing", {}).is_empty() and value.crew.navigation.mode == "idle" and value.get("local_shuttle", "").is_empty()

func _response(_sequence: int, result: Dictionary) -> void:
	if not enabled() or not result.get("ok", false) or app.surface_world == null:return
	for amount in result.get("gains", {}).values():
		if int(amount) > 0 and not progress.get("complete", false):
			progress.complete = true
			_save()

func _hint(id: String, number: int, heading: String, text: String, target: Rect2 = Rect2()) -> void:
	step = id
	counter.text = "플레이 가이드    %02d / 06" % number
	title.text = heading
	detail.text = text
	highlight = target
	card.reset_size()

func _target(control: Control) -> Rect2:
	return control.get_global_rect() if control != null and control.is_visible_in_tree() else Rect2()

func _star_marker() -> Dictionary:
	var stars = app.navigation_ui.nearby_stars
	if not stars.hovered.is_empty():return stars.hovered
	var best: Dictionary = {}
	var distance := INF
	for marker in stars.markers:
		if float(marker.distance) < distance:
			distance = float(marker.distance)
			best = marker
	return best

func _planet_marker() -> Rect2:
	if app.flight == null or not app.outside:return Rect2()
	var best := INF
	var point := Vector3.ZERO
	for planet in app.flight.planets.values():
		if not FrontierUniverse.landable(planet.body):continue
		var distance: float = app.flight.camera.global_position.distance_to(planet.node.global_position)
		if distance < best:best = distance;point = planet.node.global_position
	if best == INF:return Rect2()
	var viewport_size := Vector2(app.space_view.size)
	var marker := FrontierSpaceGuidance.project(app.flight.camera, point, viewport_size)
	var scale_factor := maxf(app.exterior_view.size.x/viewport_size.x, app.exterior_view.size.y/viewport_size.y)
	var offset: Vector2 = app.exterior_view.global_position - (viewport_size * scale_factor - app.exterior_view.size) * .5
	return Rect2(offset + marker.point * scale_factor - Vector2(14,14), Vector2(28,28))

func _process(delta: float) -> void:
	if app == null:return
	depart.visible = not letter.visible and can_open_map() and not app.any_menu_open() and not app.feedback.blocked() and not FrontierClientSettings.ensure(get_tree()).is_open()
	clock += delta
	if clock < .1:return
	clock = 0
	card.hide()
	highlight = Rect2()
	step = ""
	if letter.visible or not enabled() or app.session.latest.is_empty() or not app.session.active or app.session.latest.get("phase") != "playing":queue_redraw();return
	if get_tree().has_meta("startup_loader") or FrontierClientSettings.ensure(get_tree()).is_open() or (app.arrival != null and app.arrival.active):queue_redraw();return
	# Record the equipment visit without drawing world guidance over item/body controls.
	if app.surface_world != null and app.inventory_panel.visible and not progress.get("inventory", false):
		progress.inventory = true
		_save()
	var nav_ui = app.navigation_ui
	if app.any_menu_open() and not app.navigation_frame.visible:queue_redraw();return
	card.position = Vector2(28, 170)
	card.show()
	var value: Dictionary = app.session.latest
	var nav: Dictionary = value.crew.navigation
	if app.surface_world != null:
		var tool := FrontierEquipment.active(value.crew.members[value.self_id])
		if not progress.get("inventory", false) or tool.get("kind") != "miner":
			_hint("equipment", 5, "채집 장비 준비", "I  아이템에서 채집기를 제작 / 번호 슬롯에 장착하세요.\n장착한 번호 키로 채집기를 꺼내세요.")
		else:
			_hint("mine", 6, "첫 광물 채집", "광맥을 조준하고 왼쪽 클릭을 유지하세요.\nB 건설  F 대상 작업  자동화는 선택입니다.", Rect2(get_viewport().get_visible_rect().size * .5 - Vector2(18,18), Vector2(36,36)))
	elif not value.get("local_shuttle", "").is_empty():
		_hint("shuttle", 1, "공동 원정선으로 합류", "소형선은 같은 항성계 안에서 이동합니다.\n다음 항성계 항해는 공동 원정선에서 시작하세요.")
	elif value.self_id != value.crew.pilot_id:
		_hint("crew", 1, "승무원 항해 준비", "P  승무원에서 준비 상태를 켜세요.\n항로 선택과 출발은 조종사가 진행합니다.")
	elif nav.mode == "jump":
		_hint("transit", 3, "다음 항성계로 이동 중", "도착하면 행성을 바라보고 접근하세요.\n태양계 밖의 착륙 가능한 행성을 찾아보세요.")
	elif app.navigation_frame.visible:
		_hint("return_view", 1, "우주 화면에서 항해하기", "Tab으로 지도를 닫고 주변 항성계 표식을 찾아보세요.")
	elif not app.outside:
		_hint("outside", 1, "우주를 둘러보세요", "C  우주선 바깥 시점으로 전환하세요.")
	elif not progress.get("travel", false) or int(nav.system) == 0:
		var stars = nav_ui.nearby_stars
		var marker := _star_marker()
		if marker.is_empty():
			_hint("finding", 1, "주변 항성계 탐색 중", "항속거리 안의 항성계 표식을 준비하고 있습니다.")
		elif not stars.hovered.is_empty():
			_hint("depart", 2, "이 별로 바로 이동", "표식의 이름과 거리를 확인하세요.\nF 또는 왼쪽 클릭으로 고속 항해를 시작합니다.", Rect2(marker.point - Vector2(12,12),Vector2(24,24)))
		else:
			_hint("aim", 1, "주변 항성계 표식 찾기", "마우스로 청록색 표식을 조준하세요.\n화면 가장자리 화살표는 뒤쪽 별의 방향입니다.", Rect2(marker.point - Vector2(12,12),Vector2(24,24)))
	else:
		var near: bool = nav_ui.context_kind == "land" and nav_ui.context_ready
		_hint("land", 4, "행성 탐사 시작", "F  착륙하세요." if near else "마우스로 행성을 찾고 W/S로 접근하세요.\n주시 스캔으로 착륙 가능 여부 확인  가까이서 F", _target(nav_ui.context) if near else _planet_marker())
	queue_redraw()

func _draw() -> void:
	if not card.visible or not highlight.has_area():return
	var box := highlight.grow(5)
	draw_rect(box, FrontierInterfaceStyle.ACCENT, false, 2, true)
	var from := card.position + Vector2(card.size.x, card.size.y * .5)
	var to := box.get_center()
	if card.get_rect().grow(8).has_point(to):return
	var direction := (to - from).normalized()
	to -= direction * minf(box.size.x, box.size.y) * .5
	draw_line(from, to, Color("83d9c580"), 2, true)
	draw_line(to, to - direction.rotated(.55) * 12, FrontierInterfaceStyle.ACCENT, 2, true)
	draw_line(to, to - direction.rotated(-.55) * 12, FrontierInterfaceStyle.ACCENT, 2, true)
