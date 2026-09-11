extends RefCounted
## Only acknowledged snapshots may be a delta base. Both ends retain eight frames.
## A missing/expired base automatically falls back to a complete snapshot.
const HISTORY_LIMIT:=8
const MAX_DEPTH:=24
var history: Dictionary={}
var acknowledged: int=-1
var full_frames:=0
var delta_frames:=0

func reset()->void:
 history.clear();acknowledged=-1;full_frames=0;delta_frames=0

func remember(serial: int,value: Dictionary)->void:
 history[serial]=value.duplicate(true)
 while history.size()>HISTORY_LIMIT:history.erase(history.keys().min())

func acknowledge(serial: int)->void:
 if serial>acknowledged and history.has(serial):acknowledged=serial

func encode(value: Dictionary)->PackedByteArray:
 var maximum:=int(FrontierCrewWorld.config().snapshot_maximum_bytes)
 var full:=var_to_bytes({"format":1,"base":-1,"value":value})
 if full.size()>maximum:return PackedByteArray()
 if history.has(acknowledged):
  var patch:=_diff(history[acknowledged],value)
  var delta:=var_to_bytes({"format":1,"base":acknowledged,"patch":patch})
  if delta.size()<full.size():
   delta_frames+=1;return delta
 full_frames+=1;return full

func decode(packet: Dictionary)->Dictionary:
 if packet.get("format")!=1 or not packet.get("base") is int:return {}
 if packet.base==-1:
  return packet.value if packet.get("value") is Dictionary else {}
 if not history.has(packet.base) or not packet.get("patch") is Dictionary:return {}
 var result: Dictionary=history[packet.base].duplicate(true)
 if not _apply(result,packet.patch):return {}
 if var_to_bytes(result).size()>int(FrontierCrewWorld.config().snapshot_maximum_bytes):return {}
 return result

static func _diff(before: Dictionary,after: Dictionary,depth: int=0)->Dictionary:
 var changed: Dictionary={};var removed: Array=[];var children: Dictionary={}
 for key in before:
  if not after.has(key):removed.append(key)
 for key in after:
  if before.has(key) and before[key]==after[key]:continue
  if depth<MAX_DEPTH and before.get(key) is Dictionary and after[key] is Dictionary:
   children[key]=_diff(before[key],after[key],depth+1)
  else:changed[key]=after[key]
 return {"set":changed,"erase":removed,"children":children}

static func _apply(target: Dictionary,patch: Dictionary,depth: int=0)->bool:
 if depth>MAX_DEPTH or not patch.get("set") is Dictionary or not patch.get("erase") is Array or not patch.get("children") is Dictionary:return false
 for key in patch.erase:
  if not target.has(key) or patch.set.has(key) or patch.children.has(key):return false
  target.erase(key)
 for key in patch.set:
  if patch.children.has(key):return false
  target[key]=patch.set[key]
 for key in patch.children:
  if not target.get(key) is Dictionary or not patch.children[key] is Dictionary:return false
  if not _apply(target[key],patch.children[key],depth+1):return false
 return true
