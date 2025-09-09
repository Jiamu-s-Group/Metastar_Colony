class_name State_Manager
extends Node

var states_array: Array = []
@onready var current: Basic_State # 初始状态

func _ready() -> void:
	states_array = get_children() # 获取状态列表
	current = states_array[0]
	current.enter() #进入默认状态

func _physics_process(delta: float) -> void:
	current.process() #执行状态中的程序

func change_state(id: int) -> void: #切换状态
	current.exit()
	current = states_array[id]
	current.enter()
	
