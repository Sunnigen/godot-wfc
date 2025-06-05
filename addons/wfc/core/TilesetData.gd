extends Resource
class_name TilesetData

# Core tileset properties
@export var tile_size: int = 16
@export var tile_textures: Dictionary = {}  # tile_id (int) -> Texture2D
@export var adjacency_rules: Dictionary = {}  # tile_id -> Array[Array] for [S,E,N,W] sets
@export var base_probabilities: Dictionary = {}  # tile_id -> Array[float] for [S,E,N,W] weights

# Direction constants (matching Python version)
enum Direction { SOUTH = 0, EAST = 1, NORTH = 2, WEST = 3 }

# Helper arrays for direction operations
const DIRECTION_NAMES = ["South", "East", "North", "West"]
const DIRECTION_OFFSETS = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

func _init():
	# Initialize with blank tile (ID 0)
	add_blank_tile()

func add_blank_tile():
	"""Add the default blank/empty tile (ID 0)"""
	tile_textures[0] = _create_blank_texture()
	adjacency_rules[0] = [[], [], [], []]  # No adjacency rules for blank
	base_probabilities[0] = [0.0, 0.0, 0.0, 0.0]  # Blank has no probability

func add_tile(tile_id: int, texture: Texture2D, adjacent_tiles: Array, probabilities: Array = [1.0, 1.0, 1.0, 1.0]):
	"""
	Add a tile to the tileset
	
	Args:
		tile_id: Unique identifier for the tile
		texture: Texture2D for visual display
		adjacent_tiles: Array of 4 arrays, each containing valid neighbor tile IDs for [S,E,N,W]
		probabilities: Array of 4 floats for probability weights [S,E,N,W]
	"""
	if adjacent_tiles.size() != 4:
		push_error("TilesetData: adjacent_tiles must have exactly 4 elements [S,E,N,W]")
		return
	
	if probabilities.size() != 4:
		push_error("TilesetData: probabilities must have exactly 4 elements [S,E,N,W]")
		return
	
	tile_textures[tile_id] = texture
	adjacency_rules[tile_id] = adjacent_tiles
	base_probabilities[tile_id] = probabilities
	

func get_adjacent_tiles(tile_id: int, direction: Direction) -> Array:
	"""Get array of tile IDs that can be placed adjacent to given tile in given direction"""
	if tile_id in adjacency_rules:
		return adjacency_rules[tile_id][direction]
	return []

func get_probability(tile_id: int, direction: Direction) -> float:
	"""Get probability weight for tile in given direction"""
	if tile_id in base_probabilities:
		return base_probabilities[tile_id][direction]
	return 0.0

func get_all_tile_ids() -> Array:
	"""Get array of all tile IDs in this tileset"""
	return tile_textures.keys()

func get_non_blank_tile_ids() -> Array:
	"""Get array of all non-blank tile IDs"""
	var tiles = tile_textures.keys()
	tiles.erase(0)  # Remove blank tile
	return tiles

func validate() -> bool:
	"""Validate tileset consistency"""
	var errors = []
	
	# Check that all tiles have matching data structures
	for tile_id in tile_textures.keys():
		if not tile_id in adjacency_rules:
			errors.append("Tile %d missing adjacency rules" % tile_id)
		if not tile_id in base_probabilities:
			errors.append("Tile %d missing probabilities" % tile_id)
	
	# Check adjacency symmetry (if A can connect to B, B should be able to connect to A)
	for tile_id in adjacency_rules.keys():
		for direction in range(4):
			var adjacent_tiles = adjacency_rules[tile_id][direction]
			var opposite_dir = get_opposite_direction(direction)
			
			for adjacent_id in adjacent_tiles:
				if adjacent_id in adjacency_rules:
					var reverse_adjacent = adjacency_rules[adjacent_id][opposite_dir]
					if not tile_id in reverse_adjacent:
						errors.append("Asymmetric adjacency: Tile %d -> %d (dir %d) not symmetric" % [tile_id, adjacent_id, direction])
	
	if errors.size() > 0:
		push_error("TilesetData validation failed:\n" + "\n".join(errors))
		return false
	
	print("TilesetData validation passed: %d tiles" % tile_textures.size())
	return true

func get_opposite_direction(direction: Direction) -> Direction:
	"""Get opposite direction for adjacency checking"""
	match direction:
		Direction.SOUTH: return Direction.NORTH
		Direction.EAST: return Direction.WEST
		Direction.NORTH: return Direction.SOUTH
		Direction.WEST: return Direction.EAST
		_: return Direction.SOUTH

func is_boundary_constrained(tile_id: int, direction: Direction) -> bool:
	"""Check if tile requires being at a specific boundary due to empty adjacency rules"""
	if tile_id in adjacency_rules:
		return adjacency_rules[tile_id][direction].is_empty()
	return false

func get_required_boundaries(tile_id: int) -> Array[Direction]:
	"""Get all boundaries this tile requires (directions with empty adjacency)"""
	var boundaries: Array[Direction] = []
	for direction in [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]:
		if is_boundary_constrained(tile_id, direction):
			boundaries.append(direction)
	return boundaries

func _create_blank_texture() -> ImageTexture:
	"""Create a transparent texture for blank tiles"""
	var image = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

# Static factory method for testing
static func create_test_tileset() -> TilesetData:
	"""Create a simple 2x2 test tileset for development"""
	var tileset = TilesetData.new()
	tileset.tile_size = 16
	
	# Create simple colored tiles
	var colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	var tile_names = ["Red", "Green", "Blue", "Yellow"]
	
	for i in range(4):
		var tile_id = i + 1  # Start from 1 (0 is blank)
		var texture = _create_colored_texture(colors[i], tileset.tile_size)
		
		
		# Simple adjacency rules: each tile can connect to any other tile
		var adjacent_tiles = [
			[1, 2, 3, 4],  # South: all tiles
			[1, 2, 3, 4],  # East: all tiles  
			[1, 2, 3, 4],  # North: all tiles
			[1, 2, 3, 4]   # West: all tiles
		]
		
		# Equal probabilities
		var probabilities = [1.0, 1.0, 1.0, 1.0]
		
		tileset.add_tile(tile_id, texture, adjacent_tiles, probabilities)
	
	if tileset.validate():
		print("Test tileset created successfully with %d tiles" % tileset.get_non_blank_tile_ids().size())
	
	return tileset

static func _create_colored_texture(color: Color, size: int) -> ImageTexture:
	"""Helper to create solid color texture"""
	var image = Image.create(size, size, false, Image.FORMAT_RGB8)
	image.fill(color)
	
	var texture = ImageTexture.create_from_image(image)
	
	
	return texture
