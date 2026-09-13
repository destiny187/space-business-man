extends Control
## Screen-space ordnance warning: no solid geometry across the firing lane.
var view: FrontierIncidentView
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if view==null or view.blocked():return
	var screen:=get_viewport_rect().size
	for row in view.rows.values():
		if not FrontierCooperTechSquads.enabled(row) or row.hp<=0 or row.robot_role!="bastion" or row.phase not in ["aiming","projectile"] or row.aim.is_empty():continue
		var at:=FrontierCrewWorld.vector(row.aim)
		var distance:=view.surface.viewer.position.distance_to(at)
		if distance>14:continue
		var behind:=view.camera.is_position_behind(at)
		var p: Vector2=view.camera.unproject_position(at+Vector3.UP*.35) if not behind else screen*.5+Vector2(0,screen.y)
		p=p.clamp(Vector2(48,80),screen-Vector2(48,100))
		var danger:=distance<float(FrontierCooperTechSquads.spec(row).blast_radius)+.7
		var color:=Color("ff6654") if danger else Color("edb77c")
		color.a=.8+.2*sin(view.elapsed*16)
		# Four small brackets and a fuse identify explosive danger without hiding ground.
		for i in 4:
			var a:=float(i)*PI*.5;var u:=Vector2(cos(a),sin(a));var v:=Vector2(-u.y,u.x)
			draw_polyline(PackedVector2Array([p+u*12+v*5,p+u*17,p+u*12-v*5]),Color(0,0,0,.65),5,true)
			draw_polyline(PackedVector2Array([p+u*12+v*5,p+u*17,p+u*12-v*5]),color,2,true)
		draw_rect(Rect2(p-Vector2(3,4),Vector2(6,9)),color)
		draw_polyline(PackedVector2Array([p+Vector2(0,-4),p+Vector2(0,-8),p+Vector2(4,-9)]),color,2,true)
