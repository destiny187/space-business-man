class_name FrontierCrewSnapshotTransport
extends RefCounted
## Each packet is independently compressed. Partial frames never reach gameplay.
const MAX_IN_FLIGHT:=3
const EXPIRY_MS:=1000
var frames: Dictionary={}
var received_serial: int=-1
static func fragments(value: Dictionary) -> Array[PackedByteArray]:
	return fragments_raw(var_to_bytes(value))
static func fragments_raw(raw: PackedByteArray) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray]=[]
	var config:=FrontierCrewWorld.config()
	if raw.is_empty() or raw.size()>int(config.snapshot_maximum_bytes):return result
	var packed:=raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if packed.size()>int(config.snapshot_maximum_compressed_bytes):return result
	var size:=int(config.snapshot_fragment_bytes)
	for offset in range(0,packed.size(),size):result.append(packed.slice(offset,mini(offset+size,packed.size())))
	return result
func reset() -> void:
	frames.clear();received_serial=-1
func accept(serial: int,index: int,count: int,data: PackedByteArray,now_ms: int) -> Dictionary:
	var config:=FrontierCrewWorld.config()
	var size:=int(config.snapshot_fragment_bytes)
	var maximum:=int(config.snapshot_maximum_compressed_bytes)
	if serial<=received_serial or serial<0 or count<1 or count>ceili(float(maximum)/size) or index<0 or index>=count:return {}
	if data.is_empty() or data.size()>size or (index<count-1 and data.size()!=size):return {}
	for key in frames.keys():
		if now_ms-int(frames[key].started)>EXPIRY_MS:frames.erase(key)
	if not frames.has(serial):
		if frames.size()>=MAX_IN_FLIGHT:
			var oldest: int=frames.keys().min()
			if serial<oldest:return {}
			frames.erase(oldest)
		frames[serial]={"count":count,"started":now_ms,"parts":{}}
	var frame: Dictionary=frames[serial]
	if int(frame.count)!=count:return {}
	if frame.parts.has(index):return {}
	frame.parts[index]=data
	if frame.parts.size()!=count:return {}
	var packed:=PackedByteArray()
	for part in count:packed.append_array(frame.parts[part])
	frames.erase(serial)
	if packed.size()>maximum:return {}
	var raw:=packed.decompress_dynamic(int(config.snapshot_maximum_bytes),FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():return {}
	var value: Variant=bytes_to_var(raw) # Objects are never deserialized.
	if not value is Dictionary:return {}
	received_serial=serial
	for key in frames.keys():
		if key<=serial:frames.erase(key)
	return value
