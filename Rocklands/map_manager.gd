# MapManager.gd
extends Node
# 将自定义类从 TileData 重命名为 CellData，以避免与 Godot 内置类冲突
enum TileType {
	SAND,      # 沙子
	DIRT,      # 泥土
	PEAT,      # 泥炭 (棕色那个)
	STONE,     # 浅色石头
	HARD_STONE # 深色石头
}

# 1. 这里是第一个修改点：重命名类
class CellData:
	var type: TileType
	var has_water: bool = false
	var health: int = 100

	func _init(p_type: TileType):
		self.type = p_type

# --- 节点引用 ---
@onready var terrain_tilemap = $"../Terrain"
@onready var water_tilemap = $"../Water"

# --- 数据存储 ---
var map_data: Dictionary = {}

# --- 建立图块图谱坐标到枚举类型的映射 ---
# 你需要根据你的 TileSet 编辑器来修改这里的 Vector2i 坐标！
const ATLAS_TO_TYPE_MAP: Dictionary = {
	Vector2i(0, 0): TileType.SAND,       # 沙子在 (0,0) 	
	Vector2i(0, 1): TileType.DIRT,       # 泥土在 (0,1) 	
	Vector2i(0, 2): TileType.PEAT,       # 泥炭在 (0,2) 	
	Vector2i(0, 3): TileType.STONE,      # 石头在 (0,3) 	
	Vector2i(0, 4): TileType.HARD_STONE  # 硬石在 (0,4)
}


func _ready():
	load_map_from_tilemaps()
	print("地图数据加载完成！总共加载了 ", map_data.size(), " 个图块的数据。")


func load_map_from_tilemaps():
	map_data.clear()
	
	if not terrain_tilemap or not water_tilemap:
		#print_err("错误：地形(Terrain)或水(Water)的 TileMap 没有在 MapManager 的检查器中设置！")
		return

	var used_cells = terrain_tilemap.get_used_cells()
	
	for coords in used_cells:
		var atlas_coords: Vector2i = terrain_tilemap.get_cell_atlas_coords(coords)
		
		if ATLAS_TO_TYPE_MAP.has(atlas_coords):
			var tile_type: TileType = ATLAS_TO_TYPE_MAP[atlas_coords]
			
			# 2. 这里是第二个修改点：使用新的类名创建实例
			var new_cell_data = CellData.new(tile_type)
			
			if water_tilemap.get_cell_source_id(coords) != -1:
				new_cell_data.has_water = true
			
			map_data[coords] = new_cell_data
		else:
			print("警告：在坐标 ", coords, " 发现一个未知的地形图块，其图谱坐标为 ", atlas_coords)


# --- 公共函数，让其他脚本可以访问地图数据 ---
# 3. 这里是第三个修改点：更新函数的返回类型提示
func get_tile_data(coords: Vector2i) -> CellData:
	return map_data.get(coords, null)

# --- 当游戏逻辑改变了数据后，用来更新视觉的函数 ---
func update_tile_visuals(coords: Vector2i):
	var data = get_tile_data(coords)
	
	if data:
		if not data.has_water:
			water_tilemap.erase_cell(coords)
	else:
		terrain_tilemap.erase_cell(coords)
		water_tilemap.erase_cell(coords)
