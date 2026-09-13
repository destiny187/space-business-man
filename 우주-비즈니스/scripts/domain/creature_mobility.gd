extends RefCounted
## Small per-species authoring metadata. Loaded once per used species, never scans the roster.
static var cache: Dictionary={}
static func profile(id: String) -> Dictionary:
 if cache.has(id):return cache[id]
 var path:="res://data/creature_fast_motion/"+id+".json"
 var result: Dictionary={}
 if FileAccess.file_exists(path):result=JSON.parse_string(FileAccess.get_file_as_string(path)).profile
 cache[id]=result
 return result

static func apply(info: Dictionary,id: String,scale_value: float) -> void:
 var data:=profile(id)
 if data.is_empty():return
 # Gameplay owns top speed. The skeletal cycle follows actual distance, even
 # above the authored reference rate; animation must not slow chase or escape.
 info.acceleration=float(data.acceleration)*scale_value
 info.turn_rate=float(data.turn_rate)
 if info.get("behavior","")=="charge":
  info.charge_ramp=minf(.24,float(info.charge_distance)/float(info.charge_speed)*.20)
  info.active=float(info.charge_distance)/float(info.charge_speed)+float(info.charge_ramp)
