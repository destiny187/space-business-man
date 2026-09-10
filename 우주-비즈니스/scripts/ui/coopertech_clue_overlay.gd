extends Control
var incident: FrontierIncidentView
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if incident==null or incident.blocked():return
	var app: FrontierCrewExpedition=incident.app;var camera: Camera3D=incident.camera
	var closest: Dictionary={};var distance:=INF
	for row in app.session.latest.get("coopertech_clues",{}).values():
		if row.body_id!=incident.surface.body.id or int(row.stage)==2:continue
		var meters:=camera.global_position.distance_to(FrontierCrewWorld.vector(row.position))
		if meters<distance:closest=row;distance=meters
	if closest.is_empty():return
	var world:=FrontierCrewWorld.vector(closest.position)+Vector3.UP*3
	var behind:=camera.is_position_behind(world)
	var point:=camera.unproject_position(world) if not behind else Vector2(size.x*.5+(size.x*.4 if (world-camera.global_position).dot(camera.global_basis.x)>0 else -size.x*.4),size.y*.55)
	point=point.clamp(Vector2(45,85),size-Vector2(160,150))
	var tint:=Color("ffb16e");var font:=get_theme_default_font()
	draw_texture_rect(load(FrontierCorporations.icon_path("coopertech")),Rect2(point-Vector2(14,14),Vector2(28,28)),false)
	draw_arc(point,18,0,TAU,24,tint,1.5,true)
	draw_string(font,point+Vector2(24,0),"폐기 로봇  %.0fm"%distance,HORIZONTAL_ALIGNMENT_LEFT,145,13,tint)
	draw_string(font,point+Vector2(24,18),"Tab 지상 좌표" if distance>35 else "전투로봇 발견",HORIZONTAL_ALIGNMENT_LEFT,145,12,Color.WHITE)
