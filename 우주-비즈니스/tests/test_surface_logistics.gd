extends SceneTree
var checks:=0
var failures:=0
class NarrowPassage extends FrontierTerrainField:
	func density(p: Vector3) -> float:return maxf(absf(p.z)-.45,maxf(-p.y,p.y-1.2))
class BrokenPassage extends FrontierTerrainField:
	func density(p: Vector3) -> float:
		var value: float=maxf(absf(p.z)-2,maxf(-p.y,p.y-3))
		return minf(value,-10) if p.x>4 and p.x<10 else value
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func run() -> void:
	var state:=FrontierSurfaceLogistics.create()
	check(FrontierSurfaceLogistics.validate(state).is_empty(),"initial logistics valid")
	check(FrontierSurfaceLogistics.load_cargo(state)==0,"no cargo from empty hand")
	state.hand_rock=13
	check(FrontierSurfaceLogistics.load_cargo(state)==8,"load respects physical capacity")
	check(state.hand_rock==5 and state.robot.cargo==8,"transfer conserves cargo")
	check(FrontierSurfaceLogistics.load_cargo(state)==0,"full robot cannot duplicate cargo")
	var world:=FrontierUniverse.new_world(71491)
	world.surface_logistics={world.location:state}
	check(FrontierUniverse.validate_world(world).is_empty(),"world validates per-planet cargo")
	var roundtrip: Dictionary=JSON.parse_string(JSON.stringify(world))
	state=roundtrip.surface_logistics[world.location]
	check(FrontierSurfaceLogistics.unload(state)==8,"persisted cargo unloads")
	check(FrontierSurfaceLogistics.unload(state)==0 and state.deliveries==1,"repeat unloading cannot duplicate delivery")
	check(FrontierSurfaceLogistics.load_cargo(state)==5,"remaining hand cargo follows")
	check(FrontierSurfaceLogistics.unload(state)==5 and state.depot_rock==13 and state.hand_rock==0,"multiple trips conserve all material")
	for patch in [{"hand_rock":-1},{"depot_rock":1.5},{"deliveries":INF},{"robot":{"id":"other"}}]:
		var invalid:=state.duplicate(true);invalid.merge(patch,true)
		check(not FrontierSurfaceLogistics.validate(invalid).is_empty(),"invalid logistics rejected")
	var cfg: Dictionary=FrontierSurfaceLogistics.config().navigation
	var narrow:=NarrowPassage.new();narrow.configure(1)
	check(FrontierTerrainNavigation.new().find_path(narrow,Vector3.ZERO,Vector3(12,0,0),cfg).points.is_empty(),"robot cannot pass insufficient width or ceiling")
	var broken:=BrokenPassage.new();broken.configure(1)
	var path:=FrontierTerrainNavigation.new().find_path(broken,Vector3.ZERO,Vector3(16,0,0),cfg)
	check(path.points.is_empty(),"removed floor cannot be crossed as a floating path")
	check(path.get("expanded",0)<=int(cfg.search_limit),"no-route search remains bounded")
	print("SURFACE_LOGISTICS_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
