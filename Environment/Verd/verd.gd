# Verd.gd (肥力系统第一版)
extends Node2D

# --- 视觉节点引用 (不变) ---
@onready var spore1 = $Spore1
@onready var spore2 = $Spore2
@onready var spore3 = $Spore3
@onready var spore4 = $Spore4
@onready var spore5 = $Spore5
@onready var spore6 = $Spore6

# --- 自身状态 ---
var current_stage: int = 0
var verd_type: int # 使用 int 来存储 MapManager.VerdType 枚举值
var time_until_next_tick: float = 0.0

# --- 与世界的连接 (不变) ---
var map_manager: Node = null
var grid_coords: Vector2i = Vector2i.ZERO


# --- 修改：初始化函数现在接受类型 ---
func initialize(manager: Node, coords: Vector2i, type: int, initial_stage: int):
	self.map_manager = manager
	self.grid_coords = coords
	self.verd_type = type
	
	global_position = map_manager.terrain_tilemap.map_to_local(coords)
	rotation_degrees = [0, 90, 180, 270].pick_random()
	
	self.time_until_next_tick = _get_next_tick_time()
	
	# 设置颜色和初始阶段
	_update_color()
	set_stage(initial_stage)


func _process(delta: float):
	if not is_instance_valid(map_manager):
		return
	
	time_until_next_tick -= delta
	
	if time_until_next_tick <= 0:
		_resolve_tick()


# --- 核心判定逻辑 (已升级) ---
func _resolve_tick():
	if not is_instance_valid(map_manager): return # 安全检查
	# --- 猩红菌的专属逻辑 ---
	if verd_type == map_manager.VerdType.CRIMSON:
		# 猩红菌不生长，它只捕食。它的“传播”就是它的全部。
		_spread()
		time_until_next_tick = _get_next_tick_time()
		return # 专属逻辑结束，直接返回
		
	var data = map_manager.get_tile_data(grid_coords)
	if not data: return
	
	# --- 新增：特殊行为限制 ---
	# 灰菌在拥挤时暂停活动
	if verd_type == map_manager.VerdType.GREY:
		var neighbor_count = 0
		var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for dir in directions:
			var neighbor_data = map_manager.get_tile_data(grid_coords + dir)
			if neighbor_data and is_instance_valid(neighbor_data.occupant):
				neighbor_count += 1
		if neighbor_count > 2:
			time_until_next_tick = _get_next_tick_time() # 重置计时器，跳过本次判定
			return

	if data.nutrient <= 0:
		set_stage(current_stage - 1)
		time_until_next_tick = _get_next_tick_time()
		return
		
	var roll = randi() % 6

	match current_stage:
		1:
			if roll == 0: _spread()
			else: _grow()
		2:
			if roll < 2: _spread()
			else: _grow()
		3:
			if roll < 3: _spread()
			else: _grow()
		4:
			_spread()
	
	time_until_next_tick = _get_next_tick_time()


# --- 行为函数 (已升级) ---
func _grow():
	# 生长前消耗养分
	_consume_nutrient()
	set_stage(current_stage + 1)

func _spread():
	# --- 新增：盖亚菌无法传播 ---
	if verd_type == map_manager.VerdType.GAIA:
		# 什么也不做，相当于本次判定无效
		return

	_consume_nutrient()
	map_manager.request_spread_from(grid_coords, verd_type, current_stage)

# --- 新增：消耗养分的具体逻辑 ---

func _consume_nutrient():

	if verd_type == map_manager.VerdType.CRIMSON:
		return

	var data = map_manager.get_tile_data(grid_coords)
	if not data: return
	
	var cost = 0.0 # 最终消耗值
	var current_terrain_type = data.type
	
	# 根据菌种类型，计算消耗
	match verd_type:
		map_manager.VerdType.GREEN, map_manager.VerdType.PURE_GREEN:
			cost = 8.0 if current_terrain_type != map_manager.TileType.DIRT or data.has_water else 1
			
		map_manager.VerdType.YELLOW:
			cost = 8.0 if current_terrain_type != map_manager.TileType.SAND or data.has_water else 0.1
			
		map_manager.VerdType.BLUE:
			cost = 8.0 if current_terrain_type != map_manager.TileType.PEAT or data.has_water else 0.1
			
		map_manager.VerdType.STONE:
			cost = 8.0 if current_terrain_type != map_manager.TileType.STONE or data.has_water else 0.0
			
		map_manager.VerdType.HARD_STONE:
			cost = 8.0 if current_terrain_type != map_manager.TileType.HARD_STONE or data.has_water else 0.0
		
		map_manager.VerdType.AQUATIC:
			cost = 8.0 if not data.has_water else 0.1 # 在陆地上高消耗，在水里低消耗
		
		map_manager.VerdType.MYCELIAL:
			cost = 7.0 # 高速行动的高昂代价
		
		map_manager.VerdType.GAIA:
			cost = -0.1 # 负消耗，即恢复
			
		map_manager.VerdType.CORROSIVE:
			cost = 4.0 # 自身消耗
			# --- 腐蚀周围地块 ---
			var directions = [
				Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]
			for dir in directions:
				var neighbor_coords = grid_coords + dir
				var neighbor_data = map_manager.get_tile_data(neighbor_coords)
				if neighbor_data:
					neighbor_data.nutrient = max(0, neighbor_data.nutrient - 2.0)
		
		_: # 默认情况 (灰菌, 晶簇菌等)
			cost = 5.0

	data.nutrient = max(0, data.nutrient - cost)


func on_spread_result(success: bool):
	if not is_instance_valid(map_manager): return # 安全检查
	if not success:
		# 传播失败，需要“退还”预支的养分
		var data = map_manager.get_tile_data(grid_coords)
		if data:
			# 为了避免重复代码，我们可以临时调用一下消耗函数来获取cost值
			# 但我们只计算，不真的消耗
			var cost = 0.0
			var current_terrain_type = data.type
			match verd_type:
				map_manager.VerdType.GREEN, map_manager.VerdType.PURE_GREEN:
					cost = 4.0 if current_terrain_type != map_manager.TileType.DIRT else 2.0
				map_manager.VerdType.YELLOW:
					cost = 4.0 if current_terrain_type != map_manager.TileType.SAND else 2.0
				map_manager.VerdType.BLUE:
					cost = 4.0 if current_terrain_type != map_manager.TileType.PEAT else 2.0
				map_manager.VerdType.STONE:
					cost = 4.0 if current_terrain_type != map_manager.TileType.STONE else 2.0
				map_manager.VerdType.HARD_STONE:
					cost = 4.0 if current_terrain_type != map_manager.TileType.HARD_STONE else 2.0
				map_manager.VerdType.MYCELIAL:
					cost = 5.0
				map_manager.VerdType.GAIA:
					cost = -1.0
				map_manager.VerdType.CORROSIVE:
					cost = 2.0
				_:
					cost = 2.0
			
			data.nutrient += cost

	set_stage(current_stage - 1)


# --- 状态管理 (基本不变) ---
func set_stage(new_stage: int):
	if not is_instance_valid(map_manager): return # 安全检查
	current_stage = clamp(new_stage, 0, 4)
	
	if current_stage == 0:
		map_manager.on_verd_death(grid_coords)
		queue_free()
	else:
		update_visuals(current_stage)


# --- 辅助函数 (已升级) ---
func _get_next_tick_time() -> float:
	if not is_instance_valid(map_manager): return 9999.0 # 安全检查
	match verd_type:
		map_manager.VerdType.MYCELIAL:
			return randf_range(0.03, 0.7) # (3.0, 7.0)
		map_manager.VerdType.CRIMSON:
			# 猩红菌的捕食周期更长，给其他菌种留下喘息之机
			return randf_range(0.5, 0.7) # (50.0, 70.0) 
		_:
			return randf_range(0.25, 0.7) # (25.0, 35.0)

# --- 新增：根据类型设置颜色 ---
func _update_color():
	if not is_instance_valid(map_manager): return # 安全检查
	var color = map_manager.TYPE_TO_COLOR_MAP.get(verd_type, Color.WHITE)
	# Modulate 所有孢子
	for spore in [spore1, spore2, spore3, spore4, spore5, spore6]:
		if is_instance_valid(spore):
			spore.modulate = color

# 视觉更新函数 (不变)
func update_visuals(count: int):
	# ... (这个函数的内容完全不变) ...
	spore1.visible = false; spore2.visible = false; spore3.visible = false
	spore4.visible = false; spore5.visible = false; spore6.visible = false
	match count:
		1: spore5.visible = true
		2: spore3.visible = true; spore2.visible = true
		3: spore3.visible = true; spore4.visible = true; spore6.visible = true
		4: spore1.visible = true; spore2.visible = true; spore3.visible = true; spore4.visible = true

func transform_into(new_type: int):
	self.verd_type = new_type
	set_stage(1) # 被转化后，从阶段1重新开始
	_update_color() # 更新为新类型的颜色
	self.time_until_next_tick = _get_next_tick_time() # 重置计时器
