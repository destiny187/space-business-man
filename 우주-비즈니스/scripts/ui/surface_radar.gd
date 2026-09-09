class_name FrontierSurfaceRadar
extends Control
## North-up terrain survey. Cached height pixels; contacts refresh with the suit sweep.
var app: FrontierCrewExpedition
var elapsed:=0.0
var refresh_left:=0.0
var contacts: Array[Dictionary]=[]
var relief: ImageTexture
var map_center:=Vector3.INF
var body_id:=""
var range_m:=80.0
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(180,164);size=custom_minimum_size
	range_m=float(FrontierCrewSurface.config().radar.range)
func _process(delta: float) -> void:
	if not is_visible_in_tree() or app.surface_world==null:return
	elapsed+=delta;refresh_left-=delta
	if refresh_left<=0:
		refresh_left=float(FrontierCrewSurface.config().radar.sweep_seconds);refresh_contacts()
	queue_redraw()
func refresh_contacts() -> void:
	var p: Vector3=app.actors[app.session.latest.self_id].position
	if body_id!=app.surface_world.body.id:map_center=Vector3.INF;body_id=app.surface_world.body.id
	contacts.clear()
	var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(body_id,{})
	for vein in FrontierExpeditionBusiness.veins(app.surface_world.body,p):
		if not site.is_empty() and int(site.get("remaining",{}).get(vein.id,vein.capacity))<=0:continue
		var point:=Vector3(float(vein.position[0]),0,float(vein.position[2]))
		if Vector2(point.x-p.x,point.z-p.z).length()>range_m:continue
		contacts.append({"point":point,"kind":"mineral","color":Color(FrontierCatalog.entry("resources",vein.resource).color)})
	for row in app.surface_world.ecology.encounters.values():
		if not app.session.surface.ecology.observations.has(body_id+":"+row.form_id):continue
		contacts.append({"point":row.point,"kind":"life","color":FrontierInterfaceStyle.ACCENT})
	if not map_center.is_finite() or map_center.distance_to(p)>8:
		map_center=p
		var bitmap:=Image.create(32,32,false,Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var wx: float=p.x+(float(x)/31*2-1)*range_m
				var wz: float=p.z+(float(y)/31*2-1)*range_m
				var h: float=app.surface_world.terrain.field.height(wx,wz)
				var level:=clampf((h+12)/45,0,1)
				var shade:=Color("1c3038").lerp(Color("55716c"),floorf(level*6)/6)
				if Vector2(float(x)-15.5,float(y)-15.5).length()>15.5:shade.a=0
				bitmap.set_pixel(x,y,shade)
		relief=ImageTexture.create_from_image(bitmap)
func mapped(point: Vector3,p: Vector3) -> Vector2:
	return Vector2(90,92)+Vector2(point.x-p.x,point.z-p.z)/range_m*72
func marker(point: Vector3,p: Vector3,kind: String,color: Color,edge: bool=false) -> void:
	var offset:=Vector2(point.x-p.x,point.z-p.z)/range_m*72
	if offset.length()>72:
		if not edge:return
		offset=offset.normalized()*72
	var q:=Vector2(90,92)+offset
	match kind:
		"ship":draw_texture_rect(load("res://assets/ui/interface/ship.svg"),Rect2(q-Vector2.ONE*7,Vector2.ONE*14),false,color)
		"crew":draw_circle(q,4,color);draw_circle(q,6,color,false,1,true)
		"life":draw_arc(q,4,0,TAU,16,color,1.5,true)
		_:draw_colored_polygon(PackedVector2Array([q+Vector2(0,-3),q+Vector2(3,0),q+Vector2(0,3),q+Vector2(-3,0)]),color)
func _draw() -> void:
	if app==null or app.surface_world==null:return
	var p: Vector3=app.actors[app.session.latest.self_id].position
	var font:=get_theme_font("font","Label")
	if relief!=null:draw_texture_rect(relief,Rect2(18,20,144,144),false,Color(1,1,1,.9))
	for radius in [24,48,72]:draw_arc(Vector2(90,92),radius,0,TAU,64,Color("83d9c530"),1,true)
	draw_arc(Vector2(90,92),fmod(elapsed/float(FrontierCrewSurface.config().radar.sweep_seconds),1)*72,0,TAU,64,Color("83d9c550"),1,true)
	for row in contacts:marker(row.point,p,row.kind,row.color)
	var clue_index:=0
	for clue in FrontierGroundExploration.deposits(app.surface_world.body):
		var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
		if int(site.get("remaining",{}).get(clue.id,clue.capacity))<=0:continue
		var point:=Vector3(clue.position[0],0,clue.position[2])
		var color:=Color(FrontierCatalog.entry("resources",clue.resource).color)
		marker(point,p,"mineral",color,true)
		var at:=Vector2(20,178+clue_index*22)
		draw_texture_rect(FrontierResourceIcons.texture(clue.resource),Rect2(at,Vector2(18,18)),false)
		draw_string(font,at+Vector2(23,14),"%s 단서  %.0fm"%[FrontierCatalog.entry("resources",clue.resource).name,Vector2(point.x-p.x,point.z-p.z).length()],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
		clue_index+=1
	marker(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position),p,"ship",Color.WHITE,true)
	for id in app.session.latest.crew.members:
		if id==app.session.latest.self_id:continue
		var m: Dictionary=app.session.latest.crew.members[id]
		if m.area=="surface":marker(FrontierCrewWorld.vector(m.position),p,"crew",Color("efb46f"),true)
	var facing:=Vector2(-sin(app.yaw),-cos(app.yaw));var center:=Vector2(90,92)
	draw_colored_polygon(PackedVector2Array([center+facing*8,center+facing.rotated(2.4)*6,center+facing.rotated(-2.4)*6]),Color.WHITE)
	draw_string(font,Vector2(85,15),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
