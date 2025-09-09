# Player.gd
extends CharacterBody2D

# --- 状态 ID 常量 ---
# --- 状态 ---
const IDLE_STATE = 0
const MOVE_STATE = 1
const PICKUP_STATE = 2
const PLACE_STATE = 3

# --- 移动参数 ---
@export var max_speed: float = 90.0
@export var acceleration: float = 700.0
@export var friction: float = 900.0

# --- 视觉效果 ---
@export var tilt_angle: float = 0.25
@export var tilt_speed: float = 8.0

# --- 节点引用 ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# 注意：这个脚本里没有 _physics_process 函数，
# 因为状态机已经接管了逻辑处理。
# 我们只需要让 move_and_slide 生效即可。

func _physics_process(_delta):
	# move_and_slide 会自动使用 CharacterBody2D 的 velocity 属性进行移动
	# 而 velocity 会由当前的状态脚本来修改
	move_and_slide()
	
	# 视觉效果的更新可以留在这里
	update_tilt(_delta)

func update_tilt(delta: float):
	var target_rotation = (velocity.x / max_speed) * tilt_angle
	sprite.rotation = lerp(sprite.rotation, target_rotation, delta * tilt_speed)
