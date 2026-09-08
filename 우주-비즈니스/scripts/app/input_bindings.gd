class_name FrontierInput
extends RefCounted

const DEFAULTS := {"rover_seat":KEY_X,"rover_interact":KEY_F,"forward":KEY_W,"backward":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"jump":KEY_SPACE,"interact":KEY_E,"build":KEY_B,"robots":KEY_R,"technology":KEY_T,"journal":KEY_J,"planet":KEY_P,"camera":KEY_V,"rotate":KEY_Q,"save":KEY_F5,"help":KEY_F1}
const LABELS := {"rover_seat":"로버 운전석 이동","rover_interact":"차량 탑승·하차·복구","forward":"앞으로","backward":"뒤로","left":"왼쪽","right":"오른쪽","sprint":"질주","jump":"점프 / 로버 제동","interact":"상호작용","build":"건설","robots":"로봇","technology":"기술","journal":"탐사","planet":"평가","camera":"관찰 시점","rotate":"건축 회전","save":"빠른 저장","help":"도움말"}

static func apply(settings: Dictionary) -> void:
	for key in DEFAULTS:
		var action: String = "frontier_"+key
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(settings.get("bindings",{}).get(key,DEFAULTS[key])) as Key
		InputMap.action_add_event(action,event)

static func pressed(key: String) -> bool:
	return Input.is_action_pressed("frontier_"+key)

static func matches(event: InputEvent,key: String) -> bool:
	return event.is_action_pressed("frontier_"+key) and not event.is_echo()

static func text(key: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events("frontier_"+key)
	return OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() else "?"

static func rebind(settings: Dictionary,key: String,code: int) -> String:
	if not DEFAULTS.has(key) or code <= 0 or code == KEY_ESCAPE: return "ESC는 메뉴 열기·취소 키로 고정되어 있습니다."
	for other in DEFAULTS:
		if other != key and int(settings.get("bindings",{}).get(other,DEFAULTS[other])) == code:
			return "%s에 이미 사용 중인 키입니다." % LABELS[other]
	if not settings.has("bindings"): settings.bindings = {}
	settings.bindings[key] = code
	apply(settings)
	return ""
