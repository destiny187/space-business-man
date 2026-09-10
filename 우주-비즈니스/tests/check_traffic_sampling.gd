extends SceneTree
func _initialize() -> void:
	var m:=FrontierUniverse.generate(61739);var system:=702
	var initial:=FrontierSpaceTraffic.all(m,system,0)
	var near:=FrontierTrafficSampler.new();var moving:=FrontierTrafficSampler.new()
	near.sample(m,system,0,initial[0].position,[],{});moving.sample(m,system,0,initial[0].position,[],{})
	var a:=near.sample(m,system,.05,initial[0].position,[],{})
	var b:=moving.sample(m,system,.05,Vector3.ONE*1e6,[],{})
	var same: bool=a[0].id==b[0].id and a[0].position.distance_to(b[0].position)<.01
	print("TRAFFIC_CAMERA_RATE_CONTINUITY ",same);quit(0 if same else 1)
