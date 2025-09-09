# MoveState.gd
extends Basic_State

# 获取对 Player 和 State_Manager 的引用
# 我们的节点结构是 Player -> State_Manager -> MoveState
# 所以 get_owner() 是 State_Manager, get_owner().get_owner() 是 Player
@onready var character: CharacterBody2D = $"../.."
@onready var state_manager: Node = get_parent()

func enter():
	$"../../GPUParticles2D".emitting = true
	
func exit():
	$"../../GPUParticles2D".emitting = false

func process():
	# 从Godot获取物理帧的delta时间
	var delta = get_physics_process_delta_time()
	
	# 获取输入
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction != Vector2.ZERO:
		# 有输入时，加速
		var target_velocity = input_direction * character.max_speed
		character.velocity = character.velocity.move_toward(target_velocity, character.acceleration * delta)
	else:
		# 没有输入时，减速
		character.velocity = character.velocity.move_toward(Vector2.ZERO, character.friction * delta)
		# 如果完全停下了，就切换回闲置状态
		if character.velocity == Vector2.ZERO:
			state_manager.change_state(character.IDLE_STATE) # 使用在Player中定义的常量
			
	# 检查是否要拾取 (示例)
	if Input.is_action_just_pressed("action"):
		state_manager.change_state(character.PICKUP_STATE)
