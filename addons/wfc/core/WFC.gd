extends RefCounted
class_name WFC

signal tile_placed(position: Vector2i, tile_id: int)
signal generation_complete()
signal contradiction_found(position: Vector2i)
signal entropy_updated(position: Vector2i, entropy: int)

# Core data structures
var map_width: int
var map_height: int
var tileset_data: TilesetData

# WFC state
var tile_array: Array = []  # 2D array of placed tile IDs (0 = undecided)
var probability_array: Array = []  # 2D array of Dictionaries {tile_id: probability}
var undecided_positions: Array[Vector2i] = []
var lowest_entropy: Array = [Vector2i(-1, -1), 999]  # [position, entropy_value]

# Generation counters
var attempts: int = 0
var contradictions: int = 0
var completed_tiles: int = 0

func initialize(width: int, height: int, tileset: TilesetData):
	"""Initialize the WFC generator with map dimensions and tileset"""
	map_width = width
	map_height = height
	tileset_data = tileset
	
	if not tileset_data.validate():
		push_error("WFC: Invalid tileset data provided")
		return false
	
	_create_arrays()
	_reset_state()
	
	print("WFC initialized: %dx%d map with %d tiles" % [width, height, tileset_data.get_non_blank_tile_ids().size()])
	return true

func _create_arrays():
	"""Create and initialize the core arrays"""
	tile_array.clear()
	probability_array.clear()
	undecided_positions.clear()
	
	# Create 2D arrays
	for y in range(map_height):
		var tile_row = []
		var prob_row = []
		
		for x in range(map_width):
			tile_row.append(0)  # 0 = undecided
			prob_row.append({})  # Empty probability dict
			undecided_positions.append(Vector2i(x, y))
		
		tile_array.append(tile_row)
		probability_array.append(prob_row)
	
	# Initialize probabilities - all non-blank tiles possible everywhere
	var all_tiles = {}
	for tile_id in tileset_data.get_non_blank_tile_ids():
		all_tiles[tile_id] = 1.0
	
	for y in range(map_height):
		for x in range(map_width):
			probability_array[y][x] = all_tiles.duplicate()

func _reset_state():
	"""Reset generation state"""
	undecided_positions.shuffle()
	lowest_entropy = [Vector2i(-1, -1), 999]
	attempts = 0
	contradictions = 0
	completed_tiles = 0

func find_lowest_entropy() -> Vector2i:
	"""Find position with lowest entropy (fewest possible tiles)"""
	var best_pos = Vector2i(-1, -1)
	var best_entropy = 999
	
	for pos in undecided_positions:
		var entropy = probability_array[pos.y][pos.x].size()
		if entropy > 0 and entropy < best_entropy:
			best_entropy = entropy
			best_pos = pos
	
	lowest_entropy = [best_pos, best_entropy]
	entropy_updated.emit(best_pos, best_entropy)
	return best_pos

func generate_step() -> bool:
	"""
	Perform one step of WFC generation
	Returns true if step succeeded, false if contradiction or complete
	"""
	attempts += 1
	
	# Check if generation is complete
	if undecided_positions.size() == 0:
		generation_complete.emit()
		return false
	
	# Find position with lowest entropy
	var pos = find_lowest_entropy()
	if pos == Vector2i(-1, -1):
		push_error("WFC: No valid positions found")
		contradiction_found.emit(Vector2i(-1, -1))
		return false
	
	# Get possible tiles at this position
	var possible_tiles = probability_array[pos.y][pos.x]
	if possible_tiles.size() == 0:
		print("WFC: Contradiction at position (%d, %d)" % [pos.x, pos.y])
		contradictions += 1
		contradiction_found.emit(pos)
		return false
	
	# Select tile (uniform random for now)
	var selected_tile = possible_tiles.keys().pick_random()
	
	# Place tile
	place_tile(pos, selected_tile)
	
	return true

func place_tile(pos: Vector2i, tile_id: int):
	"""Place a tile at the given position and update constraints"""
	if not _is_valid_position(pos):
		push_error("WFC: Invalid position (%d, %d)" % [pos.x, pos.y])
		return
	
	# Place the tile
	tile_array[pos.y][pos.x] = tile_id
	probability_array[pos.y][pos.x] = {}  # Clear probabilities
	undecided_positions.erase(pos)
	completed_tiles += 1
	
	# Update constraints around placed tile
	_propagate_constraints(pos, tile_id)
	
	# Emit signal for UI update
	tile_placed.emit(pos, tile_id)
	
	print("WFC: Placed tile %d at (%d, %d). %d positions remaining" % [tile_id, pos.x, pos.y, undecided_positions.size()])

func _propagate_constraints(placed_pos: Vector2i, placed_tile: int):
	"""Update probabilities for all positions based on newly placed tile"""
	
	# For now, just update immediate neighbors (simple propagation)
	# TODO: Implement full map propagation for better results
	
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # S, E, N, W
	
	for i in range(4):
		var neighbor_pos = placed_pos + directions[i]
		if _is_valid_position(neighbor_pos) and tile_array[neighbor_pos.y][neighbor_pos.x] == 0:
			_update_position_probabilities(neighbor_pos)

func _update_position_probabilities(pos: Vector2i):
	"""Update probabilities for a specific position based on its neighbors"""
	var valid_tiles = {}
	
	# Start with all possible tiles
	for tile_id in tileset_data.get_non_blank_tile_ids():
		valid_tiles[tile_id] = 1.0
	
	# Check constraints from each direction
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # S, E, N, W
	
	for i in range(4):
		var neighbor_pos = pos + directions[i]
		if not _is_valid_position(neighbor_pos):
			continue
		
		var neighbor_tile = tile_array[neighbor_pos.y][neighbor_pos.x]
		if neighbor_tile == 0:  # Undecided neighbor
			continue
		
		# Get tiles that can be adjacent to the neighbor
		var opposite_dir = tileset_data.get_opposite_direction(i)
		var compatible_tiles = tileset_data.get_adjacent_tiles(neighbor_tile, opposite_dir)
		
		# Intersect with current valid tiles
		var new_valid_tiles = {}
		for tile_id in valid_tiles.keys():
			if tile_id in compatible_tiles:
				new_valid_tiles[tile_id] = valid_tiles[tile_id]
		
		valid_tiles = new_valid_tiles
	
	# Update probability array
	probability_array[pos.y][pos.x] = valid_tiles

func generate_map(max_steps: int = -1) -> bool:
	"""
	Generate complete map using WFC
	Returns true if successful, false if contradiction
	"""
	var steps = 0
	
	while undecided_positions.size() > 0:
		if max_steps > 0 and steps >= max_steps:
			print("WFC: Reached max steps (%d), stopping" % max_steps)
			break
		
		if not generate_step():
			break
		
		steps += 1
	
	var success = undecided_positions.size() == 0
	print("WFC: Generation %s after %d steps. %d contradictions." % ["completed" if success else "stopped", steps, contradictions])
	return success

func get_tile_at(pos: Vector2i) -> int:
	"""Get tile ID at position"""
	if _is_valid_position(pos):
		return tile_array[pos.y][pos.x]
	return -1

func get_probabilities_at(pos: Vector2i) -> Dictionary:
	"""Get probability dictionary at position"""
	if _is_valid_position(pos):
		return probability_array[pos.y][pos.x]
	return {}

func get_entropy_at(pos: Vector2i) -> int:
	"""Get entropy (number of possible tiles) at position"""
	return get_probabilities_at(pos).size()

func get_completion_percentage() -> float:
	"""Get percentage of map completed"""
	var total_positions = map_width * map_height
	return float(completed_tiles) / float(total_positions) * 100.0

func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is within map bounds"""
	return pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height

func get_stats() -> Dictionary:
	"""Get generation statistics"""
	return {
		"attempts": attempts,
		"contradictions": contradictions,
		"completed_tiles": completed_tiles,
		"undecided_positions": undecided_positions.size(),
		"completion_percentage": get_completion_percentage(),
		"lowest_entropy": lowest_entropy
	}