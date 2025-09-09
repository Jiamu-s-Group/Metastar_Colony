extends Node2D

@export var transition_speed: float = 5.0

# --- 颜色常量 ---
const DIM_COLOR: Color = Color(0.3, 0.3, 0.3)
const BRIGHT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DEFAULT_BG_COLOR: Color = Color("#0e1a2b")
const ROCKLANDS_BG_COLOR: Color = Color("#1c1916")
const FROSTCAP_BG_COLOR: Color = Color("#061d27")
const PYROFORGE_BG_COLOR: Color = Color("#2c0b23")

# --- 文本常量 ---
const TITLE_TEXT_MAP: Dictionary = {
	"default": "SELECT\nLOCATIONS...",
	"Area2D_Rocklands": "SECTOR SCANNED:\nROCKLANDS",
	"Area2D_Frostcap": "SECTOR SCANNED:\nFROSTCAP",
	"Area2D_Pyroforge": "SECTOR SCANNED:\nPYROFORGE\n(DANGER!)"
}
const DESCRIPTION_TEXT_MAP: Dictionary = {
	"default": "System operational.\nPlease select a planetary sector for\ndetailed analysis.",
	"Area2D_Rocklands": "Analysis:\nStable tectonic plates.\nRich in rocks.\nSafe for landing.",
	"Area2D_Frostcap": "Analysis:\nSub-zero temperatures and high-velocity\ncrystal storms detected.",
	"Area2D_Pyroforge": "Analysis:\nUnstable surface.\nExtreme volcanic activity.\nAtmospheric integrity compromised."
}
const STATUS_TEXT_MAP: Dictionary = {
	"default": "",
	"Area2D_Rocklands": "STATUS: [ACCESS GRANTED]",
	"Area2D_Frostcap": "STATUS: [ACCESS DENIED]",
	"Area2D_Pyroforge": "STATUS: [ACCESS DENIED]"
}

# --- 状态变量 ---
var current_hover_area: String = ""
var is_changing_scene: bool = false
# 打字机变量
var target_title_text: String = ""
var current_title_index: int = 0
var target_description_text: String = ""
var current_description_index: int = 0
var target_status_text: String = ""
var current_status_index: int = 0

# --- 目标颜色变量 ---
var ocean_target_color: Color = BRIGHT_COLOR
var rocklands_target_color: Color = BRIGHT_COLOR
var frostcap_target_color: Color = BRIGHT_COLOR
var pyroforge_target_color: Color = BRIGHT_COLOR
var background_target_color: Color = DEFAULT_BG_COLOR

# --- 节点引用 ---
@onready var background_rect: ColorRect = $CanvasLayerBack/ColorRect
@onready var title_label: Label = $CanvasLayerBack/Label
@onready var description_label: Label = $CanvasLayerBack/DescriptionLabel
@onready var status_label: Label = $CanvasLayerBack/StatusLabel
@onready var title_typing_timer: Timer = $TypingTimer
@onready var description_typing_timer: Timer = $DescriptionTypingTimer
@onready var status_typing_timer: Timer = $StatusTypingTimer
@onready var typing_sound: AudioStreamPlayer = $AudioStreamPlayer_Typing
@onready var ocean: Sprite2D = $Planet/Planet_Ocean
@onready var rocklands: Sprite2D = $Planet/Planet_Rocklands
@onready var frostcap: Sprite2D = $Planet/Planet_Frostcap
@onready var pyroforge: Sprite2D = $Planet/Planet_Pyroforge
# --- 新增: 进度条和其计时器的引用 ---
@onready var access_progress_bar: ProgressBar = $CanvasLayerBack/AccessProgressBar
@onready var access_timer: Timer = $AccessTimer


func _ready() -> void:
	# --- 新增: 确保进度条在游戏开始时是隐藏的 ---
	access_progress_bar.visible = false
	background_rect.color = DEFAULT_BG_COLOR
	trigger_text_update(TITLE_TEXT_MAP["default"], DESCRIPTION_TEXT_MAP["default"], STATUS_TEXT_MAP["default"])
	$AudioStreamPlayer.play()

# --- 已移除: 不再需要 _unhandled_input 函数来处理鼠标点击 ---
# func _unhandled_input(event: InputEvent) -> void: ...

func _process(delta: float) -> void:
	if is_changing_scene:
		return
	update_targets()
	apply_color_transitions(delta)

func update_targets() -> void:
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	var result = space.intersect_point(query)

	var detected_area_name = "default"
	if result.size() > 0:
		detected_area_name = result[0].collider.name

	if detected_area_name != current_hover_area:
		current_hover_area = detected_area_name
		var title = TITLE_TEXT_MAP.get(current_hover_area)
		var description = DESCRIPTION_TEXT_MAP.get(current_hover_area)
		var status = STATUS_TEXT_MAP.get(current_hover_area)
		trigger_text_update(title, description, status)

	ocean_target_color = BRIGHT_COLOR
	rocklands_target_color = BRIGHT_COLOR
	frostcap_target_color = BRIGHT_COLOR
	pyroforge_target_color = BRIGHT_COLOR
	background_target_color = DEFAULT_BG_COLOR

	if detected_area_name != "default":
		ocean_target_color = DIM_COLOR
		match detected_area_name:
			"Area2D_Rocklands":
				frostcap_target_color = DIM_COLOR
				pyroforge_target_color = DIM_COLOR
				background_target_color = ROCKLANDS_BG_COLOR
			"Area2D_Frostcap":
				rocklands_target_color = DIM_COLOR
				pyroforge_target_color = DIM_COLOR
				background_target_color = FROSTCAP_BG_COLOR
			"Area2D_Pyroforge":
				rocklands_target_color = DIM_COLOR
				frostcap_target_color = DIM_COLOR
				background_target_color = PYROFORGE_BG_COLOR

func apply_color_transitions(delta: float):
	background_rect.color = background_rect.color.lerp(background_target_color, transition_speed * delta)
	ocean.modulate = ocean.modulate.lerp(ocean_target_color, transition_speed * delta)
	rocklands.modulate = rocklands.modulate.lerp(rocklands_target_color, transition_speed * delta)
	frostcap.modulate = frostcap.modulate.lerp(frostcap_target_color, transition_speed * delta)
	pyroforge.modulate = pyroforge.modulate.lerp(pyroforge_target_color, transition_speed * delta)

func trigger_text_update(title: String, description: String, status: String):
	# --- 新增: 每当鼠标悬停区域改变时，重置并隐藏进度条 ---
	access_timer.stop()
	access_progress_bar.visible = false
	access_progress_bar.value = 0

	# 启动标题打字机
	title_typing_timer.stop()
	target_title_text = title
	current_title_index = 0
	title_label.text = ""
	title_typing_timer.start()
	
	# 启动简介打字机
	description_typing_timer.stop()
	target_description_text = description
	current_description_index = 0
	description_label.text = ""
	description_typing_timer.start()

	# 启动状态打字机
	status_typing_timer.stop()
	target_status_text = status
	current_status_index = 0
	status_label.text = ""
	match current_hover_area:
		"Area2D_Rocklands":
			status_label.modulate = Color(0.2, 1.0, 0.2)
		"Area2D_Frostcap", "Area2D_Pyroforge":
			status_label.modulate = Color(1.0, 0.2, 0.2)
		"default":
			status_label.modulate = Color(1.0, 1.0, 1.0)
	status_typing_timer.start()


# --- 打字机引擎 ---
func _on_typing_timer_timeout():
	if current_title_index < target_title_text.length():
		current_title_index += 1
		title_label.text = target_title_text.substr(0, current_title_index)
		typing_sound.play()
	else:
		title_typing_timer.stop()

func _on_description_typing_timer_timeout():
	if current_description_index < target_description_text.length():
		current_description_index += 1
		description_label.text = target_description_text.substr(0, current_description_index)
	else:
		description_typing_timer.stop()

func _on_status_typing_timer_timeout():
	if current_status_index < target_status_text.length():
		current_status_index += 1
		status_label.text = target_status_text.substr(0, current_status_index)
	else:
		status_typing_timer.stop()
		# --- 新增: 当 "ACCESS GRANTED" 文本打印完成后，启动进度条 ---
		if target_status_text == STATUS_TEXT_MAP["Area2D_Rocklands"]:
			access_progress_bar.visible = true
			access_progress_bar.value = 0
			access_timer.start()

# --- 新增: 处理进度条加载的函数 ---
func _on_access_timer_timeout():
	# 每次计时器超时（每0.02秒），就给进度条的值加 1
	access_progress_bar.value += 5

	# 如果进度条满了，并且我们还没有开始切换场景
	if access_progress_bar.value >= access_progress_bar.max_value:
		if not is_changing_scene:
			is_changing_scene = true
			access_timer.stop()
			Game.change_scene("res://Rocklands/rocklands.tscn")
