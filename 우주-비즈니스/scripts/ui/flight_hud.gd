class_name FrontierFlightHUD
extends Control

const WHITE := Color("eef3ef")
const MUTED := Color("92a5ab")
const MINT := Color("94edcf")
const GOLD := Color("ffc180")
var app: Node
var font: FontVariation
var bold: FontVariation
var clock: float = 0
var hit_time: float = 0
var pickup_time: float = 0
var pickup_text: String = ""
var milestone_time: float = 0
var milestone_text: String = ""
var previous_step: String = ""
var guide: Dictionary = {}
var radar: FrontierRadar
var styles: Dictionary = {}
var assessment: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	bold = font.duplicate()
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700.0}
	radar = FrontierRadar.new()
	radar.campaign = app.campaign
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(radar)

func feedback(resource: String,amount: int) -> void:
	pickup_text = "+%d  %s" % [amount,FrontierCatalog.entry("resources",resource).name]
	pickup_time = 1.3
	hit_time = 0.15

func refresh() -> void:
	guide = FrontierOnboarding.current(app.campaign.state)
	assessment = FrontierEvaluator.report(app.campaign.planet)
	radar.queue_redraw()
	var id: String = guide.get("id","")
	if id != previous_step and not previous_step.is_empty() and previous_step in app.campaign.profile.get("onboarding",{}).get("completed",[]):
		milestone_text = "완료 · "+FrontierOnboarding.TITLES[FrontierOnboarding.STEPS.find(previous_step)]
		milestone_time = 3.5
	previous_step = id
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	hit_time = maxf(0,hit_time-delta)
	pickup_time = maxf(0,pickup_time-delta)
	milestone_time = maxf(0,milestone_time-delta)
	queue_redraw()

func _panel(rect: Rect2,color: Color = Color(0.025,0.055,0.075,0.90),accent: bool = false) -> void:
	var key: String = color.to_html()
	if not styles.has(key):
		var created := StyleBoxFlat.new()
		created.bg_color = color; created.border_color = Color(0.40,0.66,0.66,0.25)
		created.set_border_width_all(1); created.set_corner_radius_all(6)
		styles[key] = created
	var style: StyleBoxFlat = styles[key]
	draw_style_box(style,rect)
	if accent: draw_rect(Rect2(rect.position,Vector2(3,rect.size.y)),MINT)

func _text(at: Vector2,value: String,px: int = 16,color: Color = WHITE,strong: bool = false,width: float = -1) -> void:
	draw_string(bold if strong else font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,px,color)

func _lines(at: Vector2,value: String,width: float,px: int = 14,color: Color = MUTED) -> void:
	var line: String = ""
	var y: float = at.y
	for word in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x > width and not line.is_empty():
			_text(Vector2(at.x,y),line,px,color); line = ""; y += px+7
		line += word+" "
	_text(Vector2(at.x,y),line,px,color)

func _bar(rect: Rect2,value: float,color: Color = MINT) -> void:
	draw_rect(rect,Color(0.24,0.37,0.40,0.45))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value,0,1),rect.size.y)),color)

func _key(pos: Vector2,label: String) -> void:
	_panel(Rect2(pos,Vector2(26,24)),Color("1d333d"))
	_text(pos+Vector2(7,17),label,12,WHITE,true)

func _draw() -> void:
	if not is_instance_valid(app) or app.quitting or not is_instance_valid(app.world) or font == null or app.campaign.planet.is_empty(): return
	var p: Dictionary = app.campaign.planet
	var scale_value: float = minf(size.x/1280,size.y/800)
	var offset: Vector2 = (size-Vector2(1280,800)*scale_value)/2
	draw_set_transform(offset,0,Vector2.ONE*scale_value)
	_panel(Rect2(24,20,1232,54))
	draw_circle(Vector2(44,47),4,MINT)
	_text(Vector2(59,51),"LOCUS",21,WHITE,true)
	_text(Vector2(150,50),p.name+"  /  원격 연결",14,MUTED)
	_text(Vector2(878,50),"%s Cr" % app._number(app.campaign.profile.credits),18,GOLD,true)
	_text(Vector2(1044,50),"%d / %d kW" % [p.power_demand,p.power_supply],16,MINT if p.power_supply >= p.power_demand else GOLD)
	_text(Vector2(1210,50),"LIVE",11,MINT)
	# A compact compass keeps the play field open.
	var heading: float = fposmod(rad_to_deg(app.world.player.rotation.y),360)
	for i in range(-3,4):
		var x: float = 640+i*44
		draw_line(Vector2(x,90),Vector2(x,97 if i%2 else 101),Color(0.8,0.95,0.9,0.45),1)
	_text(Vector2(617,118),"%03d°" % int(heading),13,MUTED)
	if not guide.is_empty():
		_panel(Rect2(24,96,330,167),Color(0.025,0.065,0.08,0.94),true)
		_text(Vector2(42,121),"개척 가이드  /  %02d · %02d" % [guide.index+1,guide.total],11,MINT,true)
		_text(Vector2(42,151),guide.title,19,WHITE,true,294)
		var detail: String = guide.detail
		for key in ["build","robots","technology","interact","planet"]: detail = detail.replace(OS.get_keycode_string(FrontierInput.DEFAULTS[key]),FrontierInput.text(key))
		_lines(Vector2(42,177),detail,294)
		_bar(Rect2(42,232,294,3),guide.progress)
		_text(Vector2(42,254),guide.counter if not guide.counter.is_empty() else FrontierInput.text("help")+"  ·  전체 단계 보기",12,MUTED,false,294)
	else:
		_panel(Rect2(24,96,285,77))
		_text(Vector2(42,124),"자유 개척",18,WHITE,true)
		_text(Vector2(42,151),FrontierInput.text("help")+" 안내서  ·  "+FrontierInput.text("planet")+" 행성 평가",13,MUTED)
	# Target marker projects the next useful destination, including off-screen guidance.
	if not guide.is_empty() and guide.position != Vector2.INF and not app.world.orbit_mode:
		var dest := Vector3(guide.position.x,2.5,guide.position.y)
		var camera: Camera3D = app.world.camera
		var dist: float = app.world.player.global_position.distance_to(dest)
		var uv: Vector2 = (camera.unproject_position(dest)-offset)/scale_value
		if camera.is_position_behind(dest): uv = Vector2(640+signf((dest-camera.global_position).dot(camera.global_basis.x))*530,340)
		uv = uv.clamp(Vector2(380,165),Vector2(1050,570))
		draw_polyline(PackedVector2Array([uv+Vector2(0,-9),uv+Vector2(8,0),uv+Vector2(0,9),uv+Vector2(-8,0),uv+Vector2(0,-9)]),GOLD,2,true)
		var marker_text: String = "%s · %.0fm" % [guide.target_label,dist]
		var label_width: float = font.get_string_size(marker_text,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		_text(uv+Vector2(-label_width-15 if uv.x > 900 else 15,5),marker_text,13,GOLD)
	# Cargo and warehouse are separate, stable locations.
	_panel(Rect2(24,645,454,94))
	_text(Vector2(42,668),"기지 보관함",11,MUTED,true)
	var x: float = 42
	for key in FrontierCatalog.table("resources"):
		var color: Color = Color(FrontierCatalog.entry("resources",key).color)
		draw_colored_polygon(PackedVector2Array([Vector2(x+7,684),Vector2(x+14,691),Vector2(x+7,698),Vector2(x,691)]),color)
		_text(Vector2(x+21,695),str(p.inventory.get(key,0)),17,WHITE,true)
		_text(Vector2(x,721),FrontierCatalog.entry("resources",key).name,11,MUTED)
		x += 84
	var cargo: int = FrontierCatalog.total(p.player.cargo)
	_panel(Rect2(24,748,454,34))
	_text(Vector2(42,771),"화물  %d / 140" % cargo,13,WHITE)
	_bar(Rect2(192,762,265,5),float(cargo)/140,GOLD if cargo >= 130 else MINT)
	# Minimal radar and environmental summary; detailed values live in the assessment.
	_panel(Rect2(1074,499,182,240))
	_text(Vector2(1090,523),"주변 탐색",12,MINT,true)
	radar.position = offset+Vector2(1093,533)*scale_value
	radar.size = Vector2(144,144)*scale_value
	var report: Dictionary = assessment if not assessment.is_empty() else FrontierEvaluator.report(p)
	_text(Vector2(1091,703),"%.0f°C  ·  O₂ %.1f%%" % [p.environment.temperature,p.environment.oxygen*100],12,WHITE)
	_text(Vector2(1091,725),"적합도 %s  /  %.0f점" % [report.grade,report.score],12,MUTED)
	_panel(Rect2(884,748,372,34))
	_text(Vector2(900,771),"M-02  /  과열 · 냉각 중" if app.overheated else "M-02  /  좌클릭 흡입 · 우클릭 펄스",13,GOLD if app.overheated else WHITE)
	if app.get("tool_heat") != null: _bar(Rect2(1080,745,176,2),app.tool_heat/100,GOLD)
	var keys: Array = ["build","robots","technology","journal","planet"]
	for i in range(keys.size()):
		var pos := Vector2(501+i*72,751)
		_key(pos,FrontierInput.text(keys[i]))
		_text(pos+Vector2(31,17),FrontierInput.LABELS[keys[i]],11,MUTED)
	if not app.world.orbit_mode:
		var center := Vector2(640,400)
		var spread: float = 7+app.world.recoil*8
		var color: Color = MINT if not app.world.target.is_empty() else Color(0.85,0.94,0.91,0.7)
		for dir in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: draw_line(center+dir*spread,center+dir*(spread+5),color,2,true)
		draw_circle(center,1.4,color)
		if hit_time > 0:
			for dir in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]: draw_line(center+dir*13,center+dir*18,GOLD,2,true)
		var label: String = ""
		var target: Dictionary = app.world.target
		if target.get("kind","") == "resource":
			var ore: Dictionary = FrontierCampaign.find_by_id(p.nodes,target.id)
			if not ore.is_empty():
				label = "%s 광맥   ·   %d" % [FrontierCatalog.entry("resources",ore.resource).name,ore.amount]
				_bar(Rect2(585,444,110,3),float(ore.amount)/float(ore.initial))
		elif target.get("kind","") == "building": label = FrontierInput.text("interact")+"  화물 반납 / 시설 관리"
		elif target.get("kind","") == "event": label = FrontierInput.text("interact")+"  이상 신호 조사"
		if not app.world.build_kind.is_empty():
			var error: String = app.campaign.placement_error(app.world.build_kind,app.world.ghost_location)
			label = "좌클릭 설치 · "+FrontierInput.text("rotate")+" 회전 · 우클릭 취소" if error.is_empty() else error
		if not label.is_empty():
			var width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			_panel(Rect2(640-width/2-15,461,width+30,34))
			_text(Vector2(640-width/2,484),label,14,WHITE)
	else: _text(Vector2(501,600),"관찰 모드  ·  "+FrontierInput.text("camera")+" 원격 조종 복귀",15,MINT)
	if pickup_time > 0: _text(Vector2(679,413-(1.3-pickup_time)*18),pickup_text,19,MINT,true)
	if milestone_time > 0:
		_panel(Rect2(442,141,420,58),Color(0.08,0.23,0.23,0.95),true)
		_text(Vector2(462,177),milestone_text,16,MINT,true,380)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
