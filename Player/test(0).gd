# IdleState.gd
extends Basic_State

@onready var character: CharacterBody2D = $"../.."
@onready var state_manager: Node = get_parent()

func process():
	var delta = get_physics_process_delta_time()
	
	# 在闲置状态，持续减速以防万一有残余速度
	character.velocity = character.velocity.move_toward(Vector2.ZERO, character.friction * delta)
	
	# 检查是否有移动输入
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		# 如果有，切换到移动状态
		state_manager.change_state(character.MOVE_STATE)
		
	# 检查是否要拾取
	if Input.is_action_just_pressed("action"):
		state_manager.change_state(character.PICKUP_STATE)
