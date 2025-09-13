# Player.gd
extends CharacterBody2D

# --- 状态 ID 常量 ---
# (这部分保持不变)
const IDLE_STATE = 0
const MOVE_STATE = 1
const PICKUP_STATE = 2
const PLACE_STATE = 3
var current_tile_coords: Vector2i = Vector2i.ZERO

# --- 移动参数 ---
@export var max_speed: float = 90.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0

# --- 视觉效果 ---
@export var tilt_angle: float = 0.25
@export var tilt_speed: float = 8.0
# --- 新增：颜色过渡参数 ---
@export var color_transition_speed: float = 10.0

# --- 节点引用 ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- 引用地图 ---
@onready var map_manager: Node = $"../MapManager"
@onready var terrain_tilemap: TileMapLayer = $"../Terrain"

# --- 改变地图颜色 ---
@onready var color_environment: ColorRect = $"../ColorRect"
@onready var terrain_label: Label = $"../CanvasLayer/Terrain"

# --- 打字机效果的 Timer ---
@onready var typing_timer: Timer = $TypingTimer

# --- 用于平滑过渡和打字机效果的变量 ---
var target_color: Color
var target_terrain_name: String = ""
var current_char_index: int = 0

# --- 高亮方块 ---
@onready var highlighter: ColorRect = $"../Highlighter"


func _ready():
	# 初始化目标颜色为当前的背景色，避免游戏开始时颜色闪烁
	target_color = color_environment.modulate
	
	# 确保高亮框在游戏开始时是隐藏的
	highlighter.visible = false


func _physics_process(delta):
	move_and_slide()
	
	var new_tile_coords: Vector2i = terrain_tilemap.local_to_map(global_position)
	
	if new_tile_coords != current_tile_coords:
		current_tile_coords = new_tile_coords
		
		# --- 更新高亮框位置的逻辑 ---
		highlighter.visible = true
		
		# 获取格子大小 (Vector2i)
		var tile_size: Vector2i = terrain_tilemap.tile_set.tile_size
		# 将格子坐标转换为世界像素坐标，并进行对齐修正
		# 在这里我们将 tile_size (Vector2i) 转换为 Vector2 来进行计算
		highlighter.global_position = terrain_tilemap.map_to_local(current_tile_coords) - (Vector2(tile_size) / 2)
		
		var cell_data = map_manager.get_tile_data(current_tile_coords)
		
		if cell_data:
			var terrain_name: String
			match cell_data.type:
				map_manager.TileType.SAND:
					terrain_name = "SAND"
					target_color = Color(2.0, 1.5, 0.0)
				map_manager.TileType.DIRT:
					terrain_name = "DIRT"
					target_color = Color(1.5, 1.0, 0.5)
				map_manager.TileType.PEAT:
					terrain_name = "PEAT"
					target_color = Color(1.0, 1.0, 1.5)
				map_manager.TileType.STONE:
					terrain_name = "STONE"
					target_color = Color(0.9, 1.0, 1.0)
				map_manager.TileType.HARD_STONE:
					terrain_name = "HARD_STONE"
					target_color = Color(0.6, 0.6, 0.7)
			
			if terrain_name != target_terrain_name:
				target_terrain_name = terrain_name
				_start_typing_effect()
		else:
			# 如果玩家走到了没有数据的区域，可以选择隐藏高亮框
			highlighter.visible = false
			pass
	
	update_tilt(delta)
	update_environment_color(delta)


# 更新倾斜效果 (原函数不变)
func update_tilt(delta: float):
	var target_rotation = (velocity.x / max_speed) * tilt_angle
	sprite.rotation = lerp(sprite.rotation, target_rotation, delta * tilt_speed)


# --- 新增：平滑更新背景颜色的函数 ---
func update_environment_color(delta: float):
	# 使用 lerp 函数让当前颜色平滑地趋向目标颜色
	color_environment.modulate = color_environment.modulate.lerp(target_color, delta * color_transition_speed)


# --- 新增：启动打字机效果的函数 ---
func _start_typing_effect():
	# 停止上一个可能还在进行的打字计时器，以防玩家快速切换地块
	typing_timer.stop()
	# 重置文本和字符索引
	terrain_label.text = "Terrain: "
	current_char_index = 0
	# 如果目标名称不为空，则开始计时
	if not target_terrain_name.is_empty():
		typing_timer.start()


# --- 新增：Timer 超时后调用的函数 (由信号连接) ---
func _on_typing_timer_timeout():
	# 检查是否还有字符需要显示
	if current_char_index < target_terrain_name.length():
		# 添加一个字符
		terrain_label.text += target_terrain_name[current_char_index]
		current_char_index += 1
		# 再次启动计时器，以显示下一个字符
		typing_timer.start()
