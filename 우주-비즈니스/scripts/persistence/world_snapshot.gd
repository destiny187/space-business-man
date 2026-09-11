extends RefCounted
## Session-owned immutable generation data can be shared by transaction drafts.
## Only references recursively frozen here qualify; mutable input always takes the full path.
static var manifests: Array[Dictionary]=[]
const CACHE_LIMIT:=4

static func own_manifest(source: Dictionary) -> Dictionary:
 var existing:=_entry(source)
 if not existing.is_empty():return source
 var owned:=source.duplicate(true)
 _freeze(owned)
 var digest:=_fingerprint(owned)
 var encoded:=JSON.stringify(owned,"",true,true)
 if manifests.size()>=CACHE_LIMIT:manifests.pop_front()
 manifests.append({"value":owned,"digest":digest,"encoded":encoded})
 return owned

static func _freeze(value: Variant) -> void:
 if value is Dictionary:
  for child in value.values():_freeze(child)
  value.make_read_only()
 elif value is Array:
  for child in value:_freeze(child)
  value.make_read_only()

static func _entry(value: Variant) -> Dictionary:
 if not value is Dictionary or not value.is_read_only():return {}
 for entry in manifests:
  if is_same(entry.value,value):return entry
 return {}

static func copy(state: Dictionary) -> Dictionary:
 var manifest: Variant=state.get("manifest")
 if _entry(manifest).is_empty():return state.duplicate(true)
 var mutable:=state.duplicate()
 mutable.erase("manifest")
 var result:=mutable.duplicate(true)
 result.manifest=manifest
 return result

static func manifest_fingerprint(value: Dictionary) -> String:
 var entry:=_entry(value)
 return entry.digest if not entry.is_empty() else _fingerprint(value)

static func _fingerprint(value: Dictionary) -> String:
 return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true).sha256_text()

static func manifest_json(state: Dictionary) -> String:
 return _entry(state.get("manifest")).get("encoded","")

# The worker receives captured immutable bytes and never accesses the shared cache.
static func encode(state: Dictionary,manifest_text: String="") -> String:
 if manifest_text.is_empty():return JSON.stringify(state,"",true,true)
 var mutable:=state.duplicate()
 mutable.erase("manifest")
 var remainder:=JSON.stringify(mutable,"",true,true)
 return '{"manifest":'+manifest_text+(","+remainder.substr(1) if remainder.length()>2 else "}")
