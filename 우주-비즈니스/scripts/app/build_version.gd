extends RefCounted
## Source checkouts follow the commit; exported apps keep their build's identity.
static var cached: String = ""

static func label() -> String:
	if not cached.is_empty(): return "버전 " + cached
	var has_checkout := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://../.git")) or FileAccess.file_exists("res://../.git")
	if not OS.has_feature("template") and has_checkout:
		var source_root := ProjectSettings.globalize_path("res://..")
		var output: Array = []
		if OS.execute("git",["-C",source_root,"log","-1","--format=%cs+%h","--abbrev=9"],output) == 0 and not output.is_empty():
			cached = str(output[0]).strip_edges().replace("-",".")
			output.clear()
			if OS.execute("git",["--no-optional-locks","-C",source_root,"status","--porcelain","--untracked-files=normal"],output) == 0 and not output.is_empty() and not str(output[0]).strip_edges().is_empty(): cached += " (개발 중)"
	if cached.is_empty() and FileAccess.file_exists("res://data/build_version.json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_version.json"))
		if data is Dictionary: cached = str(data.get("version",""))
	if cached.is_empty(): cached = "개발판 (버전 정보 없음)"
	return "버전 " + cached
