extends RefCounted
## Local, per character/expedition discovery hints. Never writes the world ledger.
var scope:=""
var records:=ConfigFile.new()
var deadlines: Dictionary={}
var loaded:=false
func configure(world_id: String,actor: String) -> void:
 scope=world_id+"/"+actor
 if not loaded:records.load("user://space_hint_memory.cfg");loaded=true
func show_hint(id: String,point: Vector3,camera: Camera3D,viewport_size: Vector2) -> bool:
 if camera.is_position_behind(point):return false
 var screen:=camera.unproject_position(point)
 if not Rect2(Vector2.ZERO,viewport_size).has_point(screen):return false
 var cfg:=FrontierFlightTelemetry.config()
 var now:=Time.get_ticks_msec()/1000.0
 if camera.global_position.distance_to(point)<=float(cfg.proximity_hint_distance) and not records.has_section_key(scope,id):
  records.set_value(scope,id,true);records.save("user://space_hint_memory.cfg");deadlines[id]=now+float(cfg.proximity_hint_seconds)
 var pointer:=viewport_size*.5 if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else camera.get_viewport().get_mouse_position()
 return screen.distance_to(pointer)<=32 or now<float(deadlines.get(id,0.0))
