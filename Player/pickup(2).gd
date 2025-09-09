# PickupState.gd
extends Basic_State

@onready var character: CharacterBody2D = $"../.."
@onready var state_manager: Node = get_parent()

func enter():
	print("进入拾取状态...")
	# 假设拾取是瞬间的，我们在这里可以播放一个音效
	# 然后立刻切换回闲置状态
	# 未来这里可以添加计时器或者等待动画完成的逻辑
	state_manager.change_state(character.IDLE_STATE)

func exit():
	print("...退出拾取状态")
