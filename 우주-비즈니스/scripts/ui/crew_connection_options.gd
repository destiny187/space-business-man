class_name FrontierCrewConnectionOptions
extends VBoxContainer
signal mode_changed(direct: bool)
var settings_path:="user://crew_connection.cfg"
var selector: OptionButton
var code: LineEdit
var address: LineEdit
var details: VBoxContainer
var progress: ProgressBar

func _ready() -> void:
	add_theme_constant_override("separation",8)
	selector=OptionButton.new();selector.name="ConnectionMode"
	selector.add_item("초대 코드로 연결");selector.add_item("IP 직접 연결")
	add_child(selector)
	code=LineEdit.new();code.name="InviteCode";code.placeholder_text="초대 코드  XXXX-XXXX-XXXX";code.max_length=14;add_child(code)
	var settings:=Button.new();settings.text="연결 설정";settings.toggle_mode=true;add_child(settings)
	details=VBoxContainer.new();add_child(details);details.hide();settings.toggled.connect(func(value: bool):details.visible=value)
	var label:=Label.new();label.text="초대 서버";details.add_child(label)
	address=LineEdit.new();address.name="RelayEndpoint";address.placeholder_text="ws://127.0.0.1:24680/relay";details.add_child(address)
	var config:=ConfigFile.new()
	config.load(settings_path)
	address.text=OS.get_environment("CREW_RELAY_URL")
	if address.text.is_empty():address.text=str(config.get_value("relay","url","ws://127.0.0.1:24680/relay"))
	var hint:=Label.new();hint.text="같은 초대 서버를 사용하는 친구와 연결합니다.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size.x=240;details.add_child(hint)
	progress=ProgressBar.new();progress.show_percentage=false;progress.indeterminate=true;progress.custom_minimum_size.y=5;add_child(progress);progress.hide()
	selector.item_selected.connect(func(_index: int):code.visible=not direct();settings.visible=not direct();details.hide();settings.button_pressed=false;mode_changed.emit(direct()))
func direct() -> bool:return selector.selected==1
func invitation() -> String:return code.text.strip_edges().to_upper().replace("-","").replace(" ","")
func endpoint() -> String:
	var url:=address.text.strip_edges()
	var config:=ConfigFile.new();config.set_value("relay","url",url);config.save(settings_path)
	return url
func set_busy(value: bool) -> void:
	selector.disabled=value;code.editable=not value;address.editable=not value;progress.visible=value
static func display_code(value: String) -> String:
	return value.substr(0,4)+"-"+value.substr(4,4)+"-"+value.substr(8,4) if value.length()==12 else value
