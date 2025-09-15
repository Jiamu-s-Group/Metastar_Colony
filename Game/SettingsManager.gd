# SettingsManager.gd
extends Node

# 保存文件的路径
const SAVE_PATH = "user://settings.cfg"

# --- 默认设置 ---
var default_settings = {
	"audio": {
		"master_volume": 0.0,
		"music_volume": 0.0,
		"sfx_volume": -6.0,
	},
	"controls": {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"interact": KEY_E,
	}
}

# --- 当前设置 (游戏运行时使用) ---
var current_settings = {}

func _ready():
	load_settings()

# --- 核心功能 ---

func load_settings():
	var config = ConfigFile.new()
	# 尝试加载文件，如果文件不存在，err 会是一个非 OK 的值
	var err = config.load(SAVE_PATH)

	if err != OK:
		# 加载失败，使用默认设置并保存一个新文件
		current_settings = default_settings.duplicate(true)
		save_settings()
	else:
		# 加载成功，读取数据
		current_settings.audio = {}
		current_settings.audio.master_volume = config.get_value("audio", "master_volume", default_settings.audio.master_volume)
		current_settings.audio.music_volume = config.get_value("audio", "music_volume", default_settings.audio.music_volume)
		current_settings.audio.sfx_volume = config.get_value("audio", "sfx_volume", default_settings.audio.sfx_volume)
		
		current_settings.controls = {}
		# 这里我们用 get_value 来确保即使存档文件损坏或缺少某个键，也不会崩溃
		current_settings.controls.move_up = config.get_value("controls", "move_up", default_settings.controls.move_up)
		current_settings.controls.move_down = config.get_value("controls", "move_down", default_settings.controls.move_down)
		current_settings.controls.move_left = config.get_value("controls", "move_left", default_settings.controls.move_left)
		current_settings.controls.move_right = config.get_value("controls", "move_right", default_settings.controls.move_right)
		current_settings.controls.interact = config.get_value("controls", "interact", default_settings.controls.interact)
	
	apply_settings()

func save_settings():
	var config = ConfigFile.new()
	
	# 将当前设置写入 config 对象
	for category in current_settings:
		for key in current_settings[category]:
			config.set_value(category, key, current_settings[category][key])
			
	# 保存到文件
	config.save(SAVE_PATH)

func apply_settings():
	# --- 应用音量设置 ---
	# AudioServer 使用分贝(dB)作为单位, 0dB是原声, 负数是减小, -80dB约等于静音
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), current_settings.audio.master_volume)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), current_settings.audio.music_volume)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), current_settings.audio.sfx_volume)

	# --- 应用按键设置 ---
	# 我们先清除旧的按键绑定，防止冲突
	InputMap.action_erase_events("move_up")
	InputMap.action_erase_events("move_down")
	InputMap.action_erase_events("move_left")
	InputMap.action_erase_events("move_right")
	InputMap.action_erase_events("interact")
	
	# 创建新的按键事件并添加到 InputMap
	var event_up = InputEventKey.new(); event_up.keycode = current_settings.controls.move_up
	var event_down = InputEventKey.new(); event_down.keycode = current_settings.controls.move_down
	var event_left = InputEventKey.new(); event_left.keycode = current_settings.controls.move_left
	var event_right = InputEventKey.new(); event_right.keycode = current_settings.controls.move_right
	var event_interact = InputEventKey.new(); event_interact.keycode = current_settings.controls.interact

	InputMap.action_add_event("move_up", event_up)
	InputMap.action_add_event("move_down", event_down)
	InputMap.action_add_event("move_left", event_left)
	InputMap.action_add_event("move_right", event_right)
	InputMap.action_add_event("interact", event_interact)
