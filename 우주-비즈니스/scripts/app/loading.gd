extends Node
## Lightweight entry scene: no game class dependencies or model preloads.
var bar: ProgressBar
var caption: Label
var phase: Label
var target: Node
var retained: Array[Resource] = []
var overlay_only := false
var destination := "res://scenes/app/main.tscn"

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_min_size(Vector2i(960, 640))
	if not overlay_only:
		destination = get_tree().get_meta("loading_destination", destination)
		get_tree().remove_meta("loading_destination")
	get_tree().set_meta("startup_loader", self)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("10191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	var title := Label.new()
	title.text = "SPACE BUSINESS MAN"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("83d9c5"))
	column.add_child(title)
	phase = Label.new()
	phase.text = "PREPARING"
	column.add_child(phase)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	for key in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("83d9c5") if key == "fill" else Color("31434d")
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(key, style)
	column.add_child(bar)
	caption = Label.new()
	caption.text = "0%"
	caption.add_theme_color_override("font_color", Color("a4b5bd"))
	column.add_child(caption)
	if not overlay_only:_run.call_deferred()

func checkpoint(value: float, label: String) -> void:
	bar.value = maxf(bar.value, value)
	phase.text = label
	caption.text = "%d%%" % int(bar.value)
	await get_tree().process_frame
	await rendered_frame()

func _resource(path: String, low: float, high: float) -> Resource:
	# Dummy rendering cannot resolve shader-valued script constants on the loading worker.
	if DisplayServer.get_name() == "headless" and path.ends_with(".tscn"):
		var resource := load(path)
		if resource != null:retained.append(resource)
		return resource
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path)
			retained.append(resource)
			return resource
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
		bar.value = maxf(bar.value, lerpf(low, high, float(progress[0]) if not progress.is_empty() else 0.0))
		caption.text = "%d%%" % int(bar.value)
		await get_tree().process_frame
	return null

func _run() -> void:
	await checkpoint(0, "PREPARING")
	var font := await _resource("res://assets/fonts/NotoSansKR.ttf", 0, 8)
	if font != null:
		phase.add_theme_font_override("font", font)
	await checkpoint(8, "실행 파일 준비")
	var packed := await _resource(destination, 8, 30) as PackedScene
	if packed == null:
		phase.text = "불러오지 못했습니다. 게임 파일을 확인해 주세요."
		var retry := Button.new()
		retry.text = "다시 시도"
		phase.get_parent().add_child(retry)
		retry.pressed.connect(func(): get_tree().set_meta("loading_destination", destination); get_tree().reload_current_scene())
		return
	if destination.ends_with("crew_expedition.tscn"):
		await checkpoint(30, "우주선 모델 읽기")
		var models := ["crew/kestrel_cabin", "crew/surveyor_suit", "ships/kestrel"]
		for i in models.size():
			var model := await _resource("res://assets/models/" + models[i] + ".glb", 30 + i * 3, 33 + i * 3)
			if model == null:
				phase.text = "모델을 읽지 못했습니다. 게임 에셋을 확인해 주세요."
				return
	await checkpoint(40 if destination.ends_with("crew_expedition.tscn") else 30, "화면 구성")
	target = packed.instantiate()
	get_tree().root.add_child(target)
	# _ready may yield between expensive initialization stages.
	while not target.get_meta("startup_complete", false):
		await get_tree().process_frame
	await checkpoint(92, "첫 화면 렌더 준비")
	var old_mode := target.process_mode
	target.process_mode = Node.PROCESS_MODE_DISABLED
	for frame in 6:
		await rendered_frame()
	await checkpoint(100, "준비 완료")
	target.process_mode = old_mode
	get_tree().remove_meta("startup_loader")
	get_tree().current_scene = target
	queue_free()

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func rendered_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _exit_tree() -> void:
	if get_tree().has_meta("startup_loader") and get_tree().get_meta("startup_loader") == self:
		get_tree().remove_meta("startup_loader")
