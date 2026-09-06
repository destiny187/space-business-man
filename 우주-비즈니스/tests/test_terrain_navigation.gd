extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var m:=FrontierUniverse.generate(71491);var body:=FrontierUniverse.body(m,0)
	var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain))
	var navigator:=FrontierTerrainNavigation.new();var cfg: Dictionary=FrontierSurfaceLogistics.config().navigation
	var result:=navigator.find_path(field,Vector3(0,2,0),Vector3(82,-21,3),cfg)
	print("NAV_RESULT count=",result.points.size()," expanded=",result.get("expanded")," ms=",result.get("milliseconds")," reason=",result.reason)
	if result.points.is_empty():printerr("FAIL: navigation must discover inclined underground path");quit(1);return
	var reverse:=FrontierTerrainNavigation.new().find_path(field,result.points[-1],Vector3(0,2,0),cfg)
	print("NAV_RETURN count=",reverse.points.size()," expanded=",reverse.get("expanded")," ms=",reverse.get("milliseconds"))
	if reverse.points.is_empty():printerr("FAIL: navigation must return");quit(1);return
	quit(0)
