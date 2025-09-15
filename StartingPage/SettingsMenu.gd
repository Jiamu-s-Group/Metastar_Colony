# SettingsMenu.gd
extends Control

# --- 节点引用 (请根据你的场景结构调整路径!) ---
@onready var master_slider = $TabContainer/Audio/MasterVolume/MasterLabel/MasterSlider# 使用 % 语法快速引用唯一名称的节点
@onready var music_slider = $TabContainer/Audio/MusicVolume/MusicLabel/MusicSlider
@onready var sfx_slider = $TabContainer/Audio/SfxVolume/SfxLabel/SfxSlider

@onready var btn_move_up = $TabContainer/Controls/Up/Label/MoveUpButton
@onready var btn_move_down = $TabContainer/Controls/Down/Label/MoveDownButton
@onready var btn_move_left = $TabContainer/Controls/Left/Label/MoveLeftButton
@onready var btn_move_right = $TabContainer/Controls/Right/Label/MoveRightButton
@onready var btn_interaction = $TabContainer/Controls/Interaction/Label/InteractionButton

@onready var back_button = $BackButton
@onready var exit_button = $ExitButton

var waiting_for_key_action = null # 用来记录我们正在为哪个动作等待按键输入

func _ready():
	btn_move_up.pressed.connect(_on_keybind_button_pressed.bind("move_up", btn_move_up))
	btn_move_down.pressed.connect(_on_keybind_button_pressed.bind("move_down", btn_move_down))
	btn_move_left.pressed.connect(_on_keybind_button_pressed.bind("move_left", btn_move_left))
	btn_move_right.pressed.connect(_on_keybind_button_pressed.bind("move_right", btn_move_right))
	btn_interaction.pressed.connect(_on_keybind_button_pressed.bind("interact", btn_interaction))
	hide() 
	
	# 将UI与当前设置同步
	update_ui_from_settings()

	# --- 连接所有信号 ---
	master_slider.value_changed.connect(_on_volume_changed.bind("master_volume", master_slider))
	music_slider.value_changed.connect(_on_volume_changed.bind("music_volume", music_slider))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx_volume", sfx_slider))
	
	btn_move_up.pressed.connect(_on_keybind_button_pressed.bind("move_up", btn_move_up))
	# ... (为其他按键绑定按钮连接信号) ...
	
	back_button.pressed.connect(hide)

func update_ui_from_settings():
	# 从 SettingsManager 获取数据并更新UI
	var audio_settings = SettingsManager.current_settings.audio
	master_slider.value = audio_settings.master_volume
	music_slider.value = audio_settings.music_volume
	sfx_slider.value = audio_settings.sfx_volume

	var control_settings = SettingsManager.current_settings.controls
	# OS.get_keycode_string() 可以把 W, S, A, D 这样的键码转换成人类可读的字符串
	btn_move_up.text = OS.get_keycode_string(control_settings.move_up)
	btn_move_down.text = OS.get_keycode_string(control_settings.move_down)
	btn_move_left.text = OS.get_keycode_string(control_settings.move_left)
	btn_move_right.text = OS.get_keycode_string(control_settings.move_right)
	btn_interaction.text = OS.get_keycode_string(control_settings.interact)

func _on_volume_changed(value, bus_name, slider):
	# 更新 SettingsManager 中的数据
	SettingsManager.current_settings.audio[bus_name] = value
	# 实时应用设置，让玩家能立刻听到效果
	SettingsManager.apply_settings()

func _on_keybind_button_pressed(action_name, button):
	# 进入“等待按键”状态
	waiting_for_key_action = action_name
	button.text = "..." # 提示用户输入

func _unhandled_input(event):
	# 如果我们正在等待按键...
	if waiting_for_key_action and event is InputEventKey and event.is_pressed():
		# 捕获到了按键！
		var key = event.keycode
		
		# 更新 SettingsManager
		SettingsManager.current_settings.controls[waiting_for_key_action] = key
		# 应用设置
		SettingsManager.apply_settings()
		# 更新UI
		update_ui_from_settings()
		
		# 退出“等待按键”状态
		waiting_for_key_action = null
		# 接受事件，防止它继续传播（比如触发玩家移动）
		get_viewport().set_input_as_handled()

# 当菜单隐藏时，确保保存设置
func _on_visibility_changed():
	if not visible:
		SettingsManager.save_settings()
		# 如果之前正在等待按键，现在取消它
		if waiting_for_key_action:
			waiting_for_key_action = null
			update_ui_from_settings()

func open_menu():
	# 1. 让自己可见
	show()
	# 2. 刷新UI，确保显示的是最新的设置
	update_ui_from_settings()
	# 3. 暂停整个游戏！
	get_tree().paused = true
	
	if get_tree().current_scene.name == "StartingPage":
		exit_button.hide()
	else:
		exit_button.show()
		

# --- 新增：关闭菜单的公共函数 ---
func close_menu():
	# 1. 隐藏自己
	hide()
	# 2. 恢复游戏运行！
	get_tree().paused = false
	# 3. 保存设置（我们之前是连接到 visibility_changed 信号，现在更明确）
	SettingsManager.save_settings()
	# 4. 如果之前正在等待按键，现在取消它
	if waiting_for_key_action:
		waiting_for_key_action = null
		update_ui_from_settings()

func _on_back_button_pressed() -> void:
	close_menu()

func _on_exit_button_pressed() -> void:
	close_menu()
	Game.change_scene("res://StartingPage/starting_page.tscn")
