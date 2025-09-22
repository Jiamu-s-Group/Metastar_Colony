# MapManager.gd (肥力系统第一版)
extends Node

const VERD_SCENE = preload("res://Environment/Verd/verd.tscn") # 确保路径正确

# --- 新增：菌种类型枚举 ---
enum VerdType {
	GREEN, PURE_GREEN, GREY, YELLOW, BLUE, STONE, HARD_STONE, 
	AQUATIC, CRIMSON, GAIA, CORROSIVE, MYCELIAL, CRYSTAL
}

# --- 新增：全局颜色映射表 ---
const TYPE_TO_COLOR_MAP: Dictionary = {
	VerdType.GREEN: Color(3.0, 4.0, 2.0),
	VerdType.PURE_GREEN: Color(2.0, 4.0, 3.0),
	VerdType.GREY: Color(2.0, 2.0, 2.0),
	VerdType.YELLOW: Color(4.0, 3.5, 0.0),
	VerdType.BLUE: Color(2.0, 2.0, 3.0),
	VerdType.STONE: Color(3.5, 3.0, 2.0),
	VerdType.HARD_STONE: Color(4.5, 3.0, 2.5),
	VerdType.AQUATIC: Color(1.0, 3.0, 4.0),
	VerdType.CRIMSON: Color(25.0, 0.0, 0.0),
	VerdType.GAIA: Color(0.0, 15.0, 20.0),
	VerdType.CORROSIVE: Color(5.0, 0.0, 15.0),
	VerdType.MYCELIAL: Color(3.5, 3.5, 3.0),
	VerdType.CRYSTAL: Color(10.0, 5.5, 9.5)
}

enum TileType {
	SAND, DIRT, PEAT, STONE, HARD_STONE
}

# --- 升级：CellData ---
class CellData:
	var type: TileType
	var has_water: bool = false
	var health: int = 100
	var occupant: Node = null
	
	# 新增肥力系统属性
	var nutrient: float = 0.0
	var max_nutrient: float = 0.0
	var is_recovering: bool = false
	var time_until_recovery_tick: float = 0.0 # 恢复计时器

	func _init(p_type: TileType):
		self.type = p_type
		# 根据地形设置初始养分和上限
		match type:
			TileType.PEAT:
				max_nutrient = 30.0
			TileType.DIRT:
				max_nutrient = 30.0
			TileType.SAND:
				max_nutrient = 20.0
			TileType.STONE, TileType.HARD_STONE:
				max_nutrient = 15.0
		nutrient = max_nutrient

# --- 节点引用 (不变) ---
@onready var terrain_tilemap: TileMapLayer = $"../Terrain"
@onready var water_tilemap: TileMapLayer = $"../Water"
@onready var verd_layer: Node2D = $"../VerdLayer"

# --- 数据存储 (不变) ---
var map_data: Dictionary = {}

# --- 图集映射 (不变) ---
const ATLAS_TO_TYPE_MAP: Dictionary = {
	Vector2i(0, 0): TileType.SAND, Vector2i(0, 1): TileType.DIRT,
	Vector2i(0, 2): TileType.PEAT, Vector2i(0, 3): TileType.STONE,
	Vector2i(0, 4): TileType.HARD_STONE
}

func _ready():
	randomize()
	load_map_from_tilemaps()
	print("地图数据加载完成！总共加载了 ", map_data.size(), " 个图块的数据。")

	# --- 修改：手动放置的绿菌现在可以指定类型 ---
	spawn_verd_at(Vector2i(58, 33), VerdType.GREEN, 1)
	spawn_verd_at(Vector2i(55, 37), VerdType.GREEN, 2)
	spawn_verd_at(Vector2i(72, 24), VerdType.GREEN, 1)
	spawn_verd_at(Vector2i(76, 23), VerdType.PURE_GREEN, 1) # 来个黄菌测试
	spawn_verd_at(Vector2i(73, 36), VerdType.YELLOW, 2) # 来个黄菌测试
	spawn_verd_at(Vector2i(85, 24), VerdType.GREEN, 1)

# --- 新增：处理养分恢复的逻辑 ---
func _process(delta: float):
	for coords in map_data.keys():
		var data: CellData = map_data[coords]
		if data.is_recovering:
			data.time_until_recovery_tick -= delta
			if data.time_until_recovery_tick <= 0:
				data.nutrient = min(data.nutrient + 2, data.max_nutrient) # 恢复2点养分
				data.time_until_recovery_tick = 7.5 # 重置15秒计时器
				# 如果养分已满，则停止恢复
				if data.nutrient >= data.max_nutrient:
					data.is_recovering = false

func load_map_from_tilemaps():
	# (函数完全不变)
	map_data.clear()
	var used_cells = terrain_tilemap.get_used_cells()
	for coords in used_cells:
		var atlas_coords = terrain_tilemap.get_cell_atlas_coords(coords)
		if ATLAS_TO_TYPE_MAP.has(atlas_coords):
			var tile_type = ATLAS_TO_TYPE_MAP[atlas_coords]
			var new_cell_data = CellData.new(tile_type)
			if water_tilemap.get_cell_source_id(coords) != -1:
				new_cell_data.has_water = true
			map_data[coords] = new_cell_data

func get_tile_data(coords: Vector2i) -> CellData:
	return map_data.get(coords, null)

# --- 修改：spawn_verd_at 现在接受一个类型参数 ---
func spawn_verd_at(coords: Vector2i, type: VerdType, initial_stage: int = 1):
	var data: CellData = get_tile_data(coords)
	if not data or is_instance_valid(data.occupant):
		return

	# 停止该地块的养分恢复
	data.is_recovering = false
	data.time_until_recovery_tick = 0
	
	var new_verd = VERD_SCENE.instantiate()
	verd_layer.add_child(new_verd)
	
	new_verd.call_deferred("initialize", self, coords, type, initial_stage)
	
	data.occupant = new_verd

# 在 MapManager.gd 中，替换这个函数

func request_spread_from(source_coords: Vector2i, source_type: VerdType, source_stage: int):
	var source_data: CellData = get_tile_data(source_coords)
	if not source_data or not is_instance_valid(source_data.occupant):
		return
		
	var source_verd = source_data.occupant

	var valid_neighbors = []
	
	# --- 猩红菌的特殊寄生逻辑 ---
	if source_type == VerdType.CRIMSON:
		var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		for dir in directions:
			var target_coords = source_coords + dir
			var target_data = get_tile_data(target_coords)
			# 目标必须是：存在、有占有者、且占有者不是猩红菌
			if target_data and is_instance_valid(target_data.occupant) and \
				target_data.occupant.verd_type != VerdType.CRIMSON:
				valid_neighbors.append(target_data.occupant) # 直接把目标实例存起来

		if not valid_neighbors.is_empty():
			var victim_verd = valid_neighbors.pick_random()
			var victim_coords = victim_verd.grid_coords # 获取受害者的坐标
		
		# --- 捕食 -> 变异逻辑 ---
			var roll = randf() # 摇一个 0.0 到 1.0 的骰子
		
			if roll < 0.20: # 20% 的概率产生晶簇菌
			# "尸体"上长出了水晶
				victim_verd.transform_into(VerdType.CRYSTAL)
			else: # 80% 的概率复制自己
			# 成功寄生
				victim_verd.transform_into(VerdType.CRIMSON)

		# 捕食成功后，捕食者自身会退化
			source_verd.on_spread_result(true)
		else:
		# 没有捕食到任何东西，它会因为“饥饿”而退化
			source_verd.on_spread_result(false)
		return
		
	# --- 其他所有菌种的常规传播逻辑 ---
	# (这部分就是我们刚刚为水生菌修改过的版本)
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var target_coords = source_coords + dir
		var target_data = get_tile_data(target_coords)
		if target_data and not is_instance_valid(target_data.occupant):
			var is_valid_terrain = false
			if source_type == VerdType.AQUATIC:
				if target_data.has_water: is_valid_terrain = true
			else:
				if not target_data.has_water: is_valid_terrain = true
			
			if is_valid_terrain:
				valid_neighbors.append(target_coords)

	if not valid_neighbors.is_empty():
		var spread_to_coords = valid_neighbors.pick_random()
		# --- 变异网络逻辑 ---
		var roll = randf() # 摇一个 0.0 到 1.0 的骰子
		var new_type = source_type # 默认情况下，后代和自己一样
		match source_type:
			VerdType.GREEN:
				if roll < 0.05: new_type = VerdType.BLUE
				elif roll < 0.10: new_type = VerdType.YELLOW
				elif roll < 0.15: new_type = VerdType.GREY
				elif roll < 0.50: new_type = VerdType.PURE_GREEN
				# 否则 (45%) 还是 GREEN
	
			VerdType.PURE_GREEN:
				if roll < 0.01: new_type = VerdType.GAIA
				elif roll < 0.03: new_type = VerdType.MYCELIAL
				elif roll < 0.04: new_type = VerdType.CORROSIVE
				elif roll < 0.05: new_type = VerdType.CRIMSON
				elif roll < 0.10: new_type = VerdType.AQUATIC
				elif roll < 0.50: new_type = VerdType.GREEN
				# 否则 (30%) 还是 PURE_GREEN
	
				# --- 新增的回归路径 ---
			VerdType.YELLOW, VerdType.BLUE, VerdType.STONE, VerdType.HARD_STONE:
				# 地形专家有 20% 的几率产生泛用的绿菌后代
				if roll < 0.05: new_type = VerdType.AQUATIC
				if roll < 0.25: new_type = VerdType.GREEN
	
			VerdType.AQUATIC:
				# 水生菌有 30% 几率变异回纯绿菌或黄菌，尤其是在尝试向陆地传播时
				if roll < 0.15: new_type = VerdType.PURE_GREEN
				if roll < 0.30: new_type = VerdType.YELLOW
		
			VerdType.GREY:
				# 灰菌有 20% 几率在环境改善时回归绿菌
				if roll < 0.20: new_type = VerdType.GREEN
				if roll < 0.40: new_type = VerdType.STONE
				if roll < 0.40: new_type = VerdType.HARD_STONE
				
			VerdType.MYCELIAL:
				# 丝菌有 20% 几率在环境改善时回归纯绿菌
				if roll < 0.20: new_type = VerdType.PURE_GREEN
				if roll < 0.40: new_type = VerdType.GREY
		
		spawn_verd_at(spread_to_coords, new_type, 1) 
		source_verd.on_spread_result(true) 
	else:
		source_verd.on_spread_result(false)

# --- 修改：on_verd_death 现在需要检查养分状态 ---
func on_verd_death(coords: Vector2i):
	var data: CellData = get_tile_data(coords)
	if data:
		data.occupant = null
		# 如果是因为养分耗尽而死，则开始恢复
		if data.nutrient <= 0:
			data.is_recovering = true
			data.time_until_recovery_tick = 15.0 # 启动15秒计时器
