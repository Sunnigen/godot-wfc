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
var propagation_waves: int = 0  # Track wave propagation performance

# Backtracking system
var placement_history: Array = []  # Stack of {position: Vector2i, tile_id: int, previous_possibilities: PackedInt64Array}
var max_backtrack_attempts: int = 5000  # Prevent infinite loops
var backtrack_depth: int = 0

# Early contradiction detection
var detected_contradictions: Array[Vector2i] = []  # Positions that hit entropy 0 during propagation

# Entropy caching system
var entropy_cache: PackedInt32Array = []  # One entropy per map position (flat array)
var entropy_dirty: PackedByteArray = []   # 1 = needs recalc, 0 = clean
var entropy_calculations: int = 0         # Track performance improvement

# Memory optimization: Bit-based possibility storage
var possibility_array: PackedInt64Array = []  # Bit flags for tile possibilities per position (64-bit for more tiles)
# TODO FUTURE: Add weighted probability system on top of bit arrays
# This will require additional data structure to store weights for positions that need them

func initialize(width: int, height: int, tileset: TilesetData):
	"""Initialize the WFC generator with map dimensions and tileset"""
	map_width = width
	map_height = height
	tileset_data = tileset
	
	print("\n=== WFC INITIALIZATION DEBUG ===")
	print("Map size: %dx%d" % [width, height])
	print("Available tiles: ", tileset_data.get_non_blank_tile_ids())
	
	if not tileset_data.validate():
		push_error("WFC: Invalid tileset data provided")
		return false
	
	_create_arrays()
	_reset_state()
	
	print("WFC initialized: %dx%d map with %d tiles" % [width, height, tileset_data.get_non_blank_tile_ids().size()])
	print("=== END INITIALIZATION DEBUG ===\n")
	return true

func _create_arrays():
	"""Create and initialize the core arrays"""
	tile_array.clear()
	probability_array.clear()
	undecided_positions.clear()
	
	# Get all non-blank tiles
	var available_tiles = tileset_data.get_non_blank_tile_ids()
	
	# Create 2D arrays
	for y in range(map_height):
		var tile_row = []
		var prob_row = []
		
		for x in range(map_width):
			tile_row.append(0)  # 0 = undecided
			
			# Initialize with all tiles possible at each position
			var probs = {}
			for tile_id in available_tiles:
				probs[tile_id] = 1.0  # Equal probability for all tiles initially
			prob_row.append(probs)
			
			undecided_positions.append(Vector2i(x, y))
		
		tile_array.append(tile_row)
		probability_array.append(prob_row)
	
	print("DEBUG: Created arrays - Sample position (0,0) has %d possible tiles" % probability_array[0][0].size())
	print("DEBUG: Possible tiles at (0,0): ", probability_array[0][0].keys())
	
	# Initialize possibility array first
	_initialize_possibility_array()
	
	# Initialize entropy cache (depends on possibility array)
	_initialize_entropy_cache()

func _reset_state():
	"""Reset generation state"""
	undecided_positions.shuffle()
	lowest_entropy = [Vector2i(-1, -1), 999]
	attempts = 0
	contradictions = 0
	completed_tiles = 0
	propagation_waves = 0
	entropy_calculations = 0
	
	# Reset backtracking state
	placement_history.clear()
	backtrack_depth = 0
	
	# Reset contradiction detection
	detected_contradictions.clear()

func find_lowest_entropy() -> Vector2i:
	"""Find position with lowest entropy using cached values"""
	# Update only positions that changed
	_update_dirty_entropies()
	
	var best_pos = Vector2i(-1, -1)
	var best_entropy = 999
	var contradiction_count = 0
	
	for pos in undecided_positions:
		var index = pos.y * map_width + pos.x
		var entropy = entropy_cache[index]
		if entropy == 0:
			contradiction_count += 1
		elif entropy < best_entropy:
			best_entropy = entropy
			best_pos = pos
	
	if best_pos == Vector2i(-1, -1):
		print("🚨 BACKTRACK TRIGGER: No valid positions found!")
		print("   Undecided positions: %d (all with entropy 0)" % undecided_positions.size())
		print("   Contradictions found: %d" % contradiction_count)
	
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
		# All remaining positions have entropy 0 - trigger backtracking
		print("🔄 ATTEMPTING BACKTRACK: All positions have entropy 0")
		if _attempt_backtrack():
			print("✅ BACKTRACK SUCCESS: Retrying generation step")
			return true  # Continue generation after backtrack
		else:
			print("❌ BACKTRACK FAILED: Generation stopped")
			contradiction_found.emit(Vector2i(-1, -1))
			return false
	
	# Get possible tiles at this position
	var possible_tiles = _get_possible_tiles(pos)
	if possible_tiles.size() == 0:
		print("🚨 NO POSSIBLE TILES: Position (%d, %d) has no valid options" % [pos.x, pos.y])
		contradictions += 1
		
		# Attempt backtracking
		if _attempt_backtrack():
			print("✅ BACKTRACK SUCCESS: Retrying generation after backtrack")
			return true
		else:
			print("❌ BACKTRACK FAILED: Generation stopped")
			contradiction_found.emit(pos)
			return false
	
	# Try tiles until one succeeds or we run out of options
	var excluded_tiles = []
	var original_possible_count = possible_tiles.size()
	
	while possible_tiles.size() > 0:
		var selected_tile = possible_tiles.pick_random()
		
		print("🔄 TRYING: Tile %d at %s (%d options remaining)" % [selected_tile, pos, possible_tiles.size()])
		
		# Attempt tentative placement
		if place_tile(pos, selected_tile):
			# Success! Tile placement worked
			print("✅ TILE SUCCESS: Tile %d placed at %s after excluding %d options" % 
				  [selected_tile, pos, excluded_tiles.size()])
			return true
		
		# Placement failed - exclude this tile and try another
		print("🚫 TILE FAILED: Excluding tile %d at %s" % [selected_tile, pos])
		excluded_tiles.append(selected_tile)
		possible_tiles.erase(selected_tile)
		_set_tile_possible(pos, selected_tile, false)  # Remove from future consideration
	
	# All tiles failed at this position
	print("💀 ALL TILES FAILED: Position %s exhausted all %d options: %s" % 
		  [pos, original_possible_count, excluded_tiles])
	contradictions += 1
	
	# Need to backtrack since no tile works at this position
	if _attempt_backtrack():
		print("✅ BACKTRACK SUCCESS: Retrying after all tiles failed")
		return true
	else:
		print("❌ BACKTRACK FAILED: Cannot recover from tile failures")
		contradiction_found.emit(pos)
		return false

func place_tile(pos: Vector2i, tile_id: int) -> bool:
	"""
	Tentatively place a tile and check for contradictions.
	Returns true if placement is successful, false if it causes contradictions.
	"""
	if not _is_valid_position(pos):
		push_error("WFC: Invalid position (%d, %d)" % [pos.x, pos.y])
		return false
	
	# Clear contradiction tracking
	detected_contradictions.clear()
	
	# Save complete state BEFORE tentative placement
	var saved_tile = tile_array[pos.y][pos.x]
	var saved_possibilities = possibility_array.duplicate()
	var saved_undecided = undecided_positions.duplicate()
	var saved_completed = completed_tiles
	
	# TENTATIVE placement - place tile and propagate
	tile_array[pos.y][pos.x] = tile_id
	probability_array[pos.y][pos.x] = {}  # Clear probabilities
	_clear_all_possibilities(pos)  # Clear bit array to match Dictionary
	_mark_entropy_dirty(pos)  # Update entropy cache
	
	# Propagate constraints to see if it causes contradictions
	_propagate_constraints(pos, tile_id)
	
	# Check if propagation created any contradictions
	if detected_contradictions.size() > 0:
		print("🚫 TENTATIVE PLACEMENT FAILED: Tile %d at %s caused %d contradictions at: %s" % 
			  [tile_id, pos, detected_contradictions.size(), detected_contradictions])
		
		# ROLLBACK - Restore previous state
		tile_array[pos.y][pos.x] = saved_tile
		possibility_array = saved_possibilities
		undecided_positions = saved_undecided
		completed_tiles = saved_completed
		
		# Mark all entropy as dirty since we restored possibilities
		for y in range(map_height):
			for x in range(map_width):
				_mark_entropy_dirty(Vector2i(x, y))
		
		return false  # Placement failed
	
	# SUCCESS - No contradictions detected, commit the placement
	print("✅ TENTATIVE PLACEMENT SUCCESS: Tile %d at %s" % [tile_id, pos])
	
	# Create history entry for backtracking
	var history_entry = {
		"position": pos,
		"tile_id": tile_id,
		"previous_possibilities": saved_possibilities,
		"previous_undecided": saved_undecided,
		"previous_completed_tiles": saved_completed
	}
	placement_history.append(history_entry)
	
	# Update final state
	undecided_positions.erase(pos)
	completed_tiles += 1
	
	# Emit signal for UI update
	tile_placed.emit(pos, tile_id)
	
	# Only print placement every 10 tiles to reduce spam
	if completed_tiles % 10 == 0 or undecided_positions.size() < 10:
		print("WFC: Committed tile %d at (%d, %d). %d positions remaining" % [tile_id, pos.x, pos.y, undecided_positions.size()])
	
	return true  # Placement successful

func _propagate_constraints(placed_pos: Vector2i, placed_tile: int):
	"""Update probabilities using wave-based propagation (breadth-first search)"""
	
	propagation_waves += 1  # Track performance
	
	# Use a queue for breadth-first propagation
	var propagation_queue: Array[Vector2i] = []
	var visited: Dictionary = {}  # Track visited positions to avoid infinite loops
	var positions_updated: int = 0
	
	# Start with the placed tile's neighbors
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]  # S, E, N, W
	
	for direction in directions:
		var neighbor_pos = placed_pos + direction
		if _is_valid_position(neighbor_pos) and tile_array[neighbor_pos.y][neighbor_pos.x] == 0:
			propagation_queue.append(neighbor_pos)
			visited[neighbor_pos] = true
	
	# Process the wave propagation
	while propagation_queue.size() > 0:
		var current_pos = propagation_queue.pop_front()
		
		# Get the previous possibilities for this position
		var old_possibilities = _get_possible_tiles(current_pos)
		
		# Update probabilities based on current constraints
		_update_position_probabilities(current_pos)
		
		# Check if possibilities changed
		var new_possibilities = _get_possible_tiles(current_pos)
		
		if _possibilities_array_changed(old_possibilities, new_possibilities):
			positions_updated += 1
			
			# If probabilities changed, add neighbors to queue for further propagation
			for direction in directions:
				var neighbor_pos = current_pos + direction
				if (_is_valid_position(neighbor_pos) and 
					tile_array[neighbor_pos.y][neighbor_pos.x] == 0 and 
					not visited.has(neighbor_pos)):
					
					propagation_queue.append(neighbor_pos)
					visited[neighbor_pos] = true
	
	# Only log major wave propagation events
	if positions_updated > 10:
		print("WFC: Large wave propagation updated %d positions" % positions_updated)

func _update_position_probabilities(pos: Vector2i):
	"""Update probabilities for a specific position based on its neighbors"""
	# Mark entropy as dirty BEFORE changing probabilities
	_mark_entropy_dirty(pos)
	
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
	
	# Apply boundary constraints - filter tiles that require specific edges
	var boundary_filtered_tiles = {}
	var boundary_rejections = 0
	
	for tile_id in valid_tiles.keys():
		var can_place = true
		var rejection_reason = ""
		
		# Check each direction for boundary requirements
		for direction in [TilesetData.Direction.NORTH, TilesetData.Direction.EAST, TilesetData.Direction.SOUTH, TilesetData.Direction.WEST]:
			if tileset_data.is_boundary_constrained(tile_id, direction):
				# This tile requires being at this boundary
				if not _is_at_edge(pos, direction):
					can_place = false
					var direction_name = ["South", "East", "North", "West"][direction]
					rejection_reason = "Tile %d requires %s boundary, but pos %s not at edge" % [tile_id, direction_name, pos]
					break
		
		if can_place:
			boundary_filtered_tiles[tile_id] = valid_tiles[tile_id]
		else:
			boundary_rejections += 1
			# Only log first few rejections to avoid spam
			if boundary_rejections <= 2:
				pass
				# Boundary rejection (only log if verbose debugging needed)
				# print("BOUNDARY: " + rejection_reason)
	
	# Only log boundary filtering when there are many rejections  
	if boundary_rejections > 5:
		print("BOUNDARY: Filtered %d tiles at %s" % [boundary_rejections, pos])
	
	valid_tiles = boundary_filtered_tiles
	
	# Early contradiction detection - check if this position has no valid tiles
	if valid_tiles.size() == 0 and tile_array[pos.y][pos.x] == 0:
		print("⚠️ CONTRADICTION DETECTED: Position %s has no valid tiles after constraint propagation" % pos)
		detected_contradictions.append(pos)
	
	# Update probability array
	probability_array[pos.y][pos.x] = valid_tiles
	
	# Update bit array to match Dictionary
	_set_all_possibilities(pos, valid_tiles.keys())

func _probabilities_changed(old_probs: Dictionary, new_probs: Dictionary) -> bool:
	"""Check if probability dictionaries are different"""
	if old_probs.size() != new_probs.size():
		return true
	
	for tile_id in old_probs.keys():
		if not new_probs.has(tile_id):
			return true
	
	return false

func _possibilities_array_changed(old_tiles: Array[int], new_tiles: Array[int]) -> bool:
	"""Check if possibility arrays are different"""
	if old_tiles.size() != new_tiles.size():
		return true
	
	# Check if all tiles in old array are in new array
	for tile_id in old_tiles:
		if not tile_id in new_tiles:
			return true
	
	return false

# Entropy Caching System

func _initialize_entropy_cache():
	"""Initialize entropy cache for all positions"""
	var total_positions = map_width * map_height
	entropy_cache.resize(total_positions)
	entropy_dirty.resize(total_positions)
	
	# Calculate initial entropy for all positions
	for y in range(map_height):
		for x in range(map_width):
			var index = y * map_width + x
			var pos = Vector2i(x, y)
			entropy_cache[index] = _get_possibility_count(pos)
			entropy_dirty[index] = 0  # Clean
			entropy_calculations += 1

func _initialize_possibility_array():
	"""Initialize bit-based possibility array for all positions"""
	var total_positions = map_width * map_height
	possibility_array.resize(total_positions)
	
	# Create bitmask with all tiles possible (using 64-bit integers)
	var all_tiles_mask = 0
	for tile_id in tileset_data.get_non_blank_tile_ids():
		all_tiles_mask |= (1 << tile_id)
	
	# Initialize all positions with all tiles possible
	for i in range(total_positions):
		possibility_array[i] = all_tiles_mask
	
	print("WFC: Initialized possibility array with %d positions" % total_positions)
	print("DEBUG: All tiles bitmask = %d" % all_tiles_mask)
	print("DEBUG: Sample possibility at index 0 = %d" % possibility_array[0])
	
	# Get all non-blank tile IDs
	var all_tile_ids = tileset_data.get_non_blank_tile_ids()
	
	# Set all tiles as possible for every position initially
	for y in range(map_height):
		for x in range(map_width):
			var pos = Vector2i(x, y)
			_set_all_possibilities(pos, all_tile_ids)

func _mark_entropy_dirty(pos: Vector2i):
	"""Mark a position's entropy as needing recalculation"""
	var index = pos.y * map_width + pos.x
	entropy_dirty[index] = 1

func _update_dirty_entropies():
	"""Update entropy cache for all dirty positions"""
	for y in range(map_height):
		for x in range(map_width):
			var index = y * map_width + x
			if entropy_dirty[index] == 1:
				var pos = Vector2i(x, y)
				entropy_cache[index] = _get_possibility_count(pos)
				entropy_dirty[index] = 0
				entropy_calculations += 1

# Phase 1: Core Bit Manipulation Methods

func _pos_to_index(pos: Vector2i) -> int:
	"""Convert 2D position to flat array index"""
	return pos.y * map_width + pos.x

func _tile_id_to_bit(tile_id: int) -> int:
	"""Convert tile ID to bit position (tile_id - 1 since tile IDs start at 1)"""
	return tile_id - 1

func _is_valid_tile_id(tile_id: int) -> bool:
	"""Check if tile ID is valid (non-zero and within tileset)"""
	if tile_id <= 0:
		return false
	var max_tiles = tileset_data.get_non_blank_tile_ids().size()
	return tile_id <= max_tiles

func _set_tile_possible(pos: Vector2i, tile_id: int, possible: bool):
	"""Set or clear a tile possibility at the given position"""
	if not _is_valid_position(pos):
		push_error("WFC: Invalid position (%d, %d)" % [pos.x, pos.y])
		return
	
	if not _is_valid_tile_id(tile_id):
		push_error("WFC: Invalid tile ID %d" % tile_id)
		return
	
	var index = _pos_to_index(pos)
	
	# Check bounds
	if index < 0 or index >= possibility_array.size():
		push_error("WFC: Index %d out of bounds for possibility_array (size: %d)" % [index, possibility_array.size()])
		return
	
	var bit_pos = _tile_id_to_bit(tile_id)
	var bit_flag = 1 << bit_pos
	
	if possible:
		# Set bit (tile is possible)
		possibility_array[index] = possibility_array[index] | bit_flag
	else:
		# Clear bit (tile is not possible)
		possibility_array[index] = possibility_array[index] & (~bit_flag)

func _is_tile_possible(pos: Vector2i, tile_id: int) -> bool:
	"""Check if a tile is possible at the given position"""
	if not _is_valid_position(pos) or not _is_valid_tile_id(tile_id):
		return false
	
	var index = _pos_to_index(pos)
	
	# Check bounds
	if index < 0 or index >= possibility_array.size():
		return false
	
	var bit_pos = _tile_id_to_bit(tile_id)
	var bit_flag = 1 << bit_pos
	
	return (possibility_array[index] & bit_flag) != 0

func _get_possible_tiles(pos: Vector2i) -> Array[int]:
	"""Get array of all possible tile IDs at the given position"""
	var possible_tiles: Array[int] = []
	
	if not _is_valid_position(pos):
		return possible_tiles
	
	var index = _pos_to_index(pos)
	
	# Check bounds
	if index < 0 or index >= possibility_array.size():
		return possible_tiles
	
	var bits = possibility_array[index]
	
	# Check each bit and add corresponding tile ID
	for tile_id in tileset_data.get_non_blank_tile_ids():
		var bit_pos = _tile_id_to_bit(tile_id)
		var bit_flag = 1 << bit_pos
		if (bits & bit_flag) != 0:
			possible_tiles.append(tile_id)
	
	return possible_tiles

func _get_possibility_count(pos: Vector2i) -> int:
	"""Get number of possible tiles at position (for entropy calculation)"""
	if not _is_valid_position(pos):
		return 0
	
	# CRITICAL: If tile is already placed, entropy is 0
	if tile_array[pos.y][pos.x] != 0:
		return 0
	
	var index = _pos_to_index(pos)
	
	# Check bounds to avoid the error
	if index < 0 or index >= possibility_array.size():
		push_error("WFC: Index %d out of bounds for possibility_array (size: %d)" % [index, possibility_array.size()])
		return 0
	
	var bits = possibility_array[index]
	
	# Count set bits using bit manipulation
	var count = 0
	while bits > 0:
		count += bits & 1  # Add 1 if lowest bit is set
		bits >>= 1         # Shift right by 1 bit
	
	return count

func _set_all_possibilities(pos: Vector2i, tile_ids: Array):
	"""Set multiple tile possibilities at once, clearing all others"""
	if not _is_valid_position(pos):
		push_error("WFC: Invalid position (%d, %d)" % [pos.x, pos.y])
		return
	
	var index = _pos_to_index(pos)
	
	# Check bounds
	if index < 0 or index >= possibility_array.size():
		push_error("WFC: Index %d out of bounds for possibility_array (size: %d)" % [index, possibility_array.size()])
		return
	
	possibility_array[index] = 0  # Clear all bits first
	
	# Set bits for each tile ID
	for tile_id in tile_ids:
		if _is_valid_tile_id(tile_id):
			var bit_pos = _tile_id_to_bit(tile_id)
			var bit_flag = 1 << bit_pos
			possibility_array[index] = possibility_array[index] | bit_flag

func _clear_all_possibilities(pos: Vector2i):
	"""Clear all tile possibilities at position"""
	if not _is_valid_position(pos):
		return
	
	var index = _pos_to_index(pos)
	
	# Check bounds
	if index < 0 or index >= possibility_array.size():
		return
	
	possibility_array[index] = 0

# Phase 1 Testing Methods

func test_bit_operations():
	"""Test Phase 1 bit operations against existing Dictionary system"""
	print("=== Phase 1 Bit Operations Test ===")
	
	# Test a few positions
	var test_positions = [Vector2i(0, 0), Vector2i(5, 5), Vector2i(map_width-1, map_height-1)]
	
	for pos in test_positions:
		if not _is_valid_position(pos):
			continue
			
		print("Testing position (%d, %d):" % [pos.x, pos.y])
		
		# Get current dictionary data
		var dict_tiles = probability_array[pos.y][pos.x].keys()
		var dict_count = probability_array[pos.y][pos.x].size()
		
		# Get bit array data
		var bit_tiles = _get_possible_tiles(pos)
		var bit_count = _get_possibility_count(pos)
		
		print("  Dictionary: " + str(dict_tiles) + " (count: " + str(dict_count) + ")")
		print("  Bit Array:  " + str(bit_tiles) + " (count: " + str(bit_count) + ")")
		
		# Check if they match
		var matches = true
		if dict_count != bit_count:
			matches = false
		else:
			for tile_id in dict_tiles:
				if not _is_tile_possible(pos, tile_id):
					matches = false
					break
		
		if matches:
			print("  ✅ MATCH")
		else:
			print("  ❌ MISMATCH!")
		
		print("")
	
	print("=== Test Individual Operations ===")
	var test_pos = Vector2i(2, 2)
	if _is_valid_position(test_pos):
		# Find an undecided position for testing, or use (2,2) if map is empty
		var found_undecided = false
		for pos in undecided_positions:
			test_pos = pos
			found_undecided = true
			break
		
		if not found_undecided and tile_array[test_pos.y][test_pos.x] != 0:
			print("  All positions are decided, skipping individual operations test")
		else:
			print("Testing individual bit operations at (" + str(test_pos.x) + ", " + str(test_pos.y) + "):")
			
			# Save original state
			var original_possibilities = _get_possible_tiles(test_pos)
			
			# Test setting/clearing specific tiles
			print("  Initial possibilities: " + str(original_possibilities))
			
			_set_tile_possible(test_pos, 1, false)
			print("  After removing tile 1: " + str(_get_possible_tiles(test_pos)))
			
			_set_tile_possible(test_pos, 1, true)  
			print("  After adding tile 1 back: " + str(_get_possible_tiles(test_pos)))
			
			_clear_all_possibilities(test_pos)
			print("  After clearing all: " + str(_get_possible_tiles(test_pos)))
			
			_set_all_possibilities(test_pos, [2, 4])
			print("  After setting [2, 4]: " + str(_get_possible_tiles(test_pos)))
			
			# Restore original state
			_set_all_possibilities(test_pos, original_possibilities)
			print("  Restored to: " + str(_get_possible_tiles(test_pos)))
	
	print("=== Phase 1 Test Complete ===")

func verify_bit_consistency():
	"""Verify bit array matches dictionary array for all positions"""
	var mismatches = 0
	var total_positions = 0
	var placed_tiles = 0
	var undecided_tiles = 0
	
	for y in range(map_height):
		for x in range(map_width):
			total_positions += 1
			var pos = Vector2i(x, y)
			
			var dict_count = probability_array[y][x].size()
			var bit_count = _get_possibility_count(pos)
			var is_placed = tile_array[y][x] != 0
			
			if is_placed:
				placed_tiles += 1
			else:
				undecided_tiles += 1
			
			if dict_count != bit_count:
				mismatches += 1
				print("  Mismatch at (" + str(x) + ", " + str(y) + "): Dict=" + str(dict_count) + ", Bit=" + str(bit_count) + ", Placed=" + str(is_placed))
	
	var matches = total_positions - mismatches
	var percentage = float(matches) / total_positions * 100.0
	print("Bit consistency check: " + str(matches) + "/" + str(total_positions) + " positions match (" + str(percentage) + "%)")
	print("  Placed tiles: " + str(placed_tiles) + ", Undecided: " + str(undecided_tiles))
	return mismatches == 0

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
	"""Get probability dictionary at position (converted from bit array)"""
	if _is_valid_position(pos):
		# Convert bit array to Dictionary format for UI compatibility
		var result = {}
		var possible_tiles = _get_possible_tiles(pos)
		for tile_id in possible_tiles:
			result[tile_id] = 1.0  # Uniform probability for now
		return result
	return {}

func get_entropy_at(pos: Vector2i) -> int:
	"""Get entropy (number of possible tiles) at position using cache"""
	if _is_valid_position(pos):
		var index = pos.y * map_width + pos.x
		# Make sure entropy is up to date
		if entropy_dirty[index] == 1:
			entropy_cache[index] = _get_possibility_count(pos)
			entropy_dirty[index] = 0
			entropy_calculations += 1
		return entropy_cache[index]
	return 0

func get_completion_percentage() -> float:
	"""Get percentage of map completed"""
	var total_positions = map_width * map_height
	return float(completed_tiles) / float(total_positions) * 100.0

func _is_valid_position(pos: Vector2i) -> bool:
	"""Check if position is within map bounds"""
	return pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height

func _is_at_edge(pos: Vector2i, direction: TilesetData.Direction) -> bool:
	"""Check if position is at the specified map edge"""
	match direction:
		TilesetData.Direction.NORTH: return pos.y == 0  # Top edge
		TilesetData.Direction.SOUTH: return pos.y == map_height - 1  # Bottom edge
		TilesetData.Direction.EAST: return pos.x == map_width - 1  # Right edge
		TilesetData.Direction.WEST: return pos.x == 0  # Left edge
		_: return false

func get_stats() -> Dictionary:
	"""Get generation statistics"""
	return {
		"attempts": attempts,
		"contradictions": contradictions,
		"completed_tiles": completed_tiles,
		"undecided_positions": undecided_positions.size(),
		"completion_percentage": get_completion_percentage(),
		"lowest_entropy": lowest_entropy,
		"propagation_waves": propagation_waves,
		"entropy_calculations": entropy_calculations,
		"backtrack_depth": backtrack_depth,
		"placement_history_size": placement_history.size()
	}

func _attempt_backtrack() -> bool:
	"""
	Attempt to backtrack when a contradiction is found
	Returns true if backtracking was successful, false if we should give up
	"""
	print("\n🔄 BACKTRACK START: Attempt %d/%d" % [backtrack_depth + 1, max_backtrack_attempts])
	print("   History size: %d placements" % placement_history.size())
	
	if placement_history.size() == 0:
		print("❌ BACKTRACK FAIL: No placement history available")
		return false
	
	if backtrack_depth >= max_backtrack_attempts:
		print("❌ BACKTRACK FAIL: Maximum attempts (%d) reached" % max_backtrack_attempts)
		return false
	
	backtrack_depth += 1
	
	# Look for a placement we can undo and retry with different tile
	for i in range(placement_history.size() - 1, -1, -1):
		var history_entry = placement_history[i]
		var pos = history_entry.position
		var rejected_tile = history_entry.tile_id
		
		# Restore state to before this placement
		_restore_state(history_entry)
		
		# Remove placements back to this point
		placement_history.resize(i)
		
		# Get possible tiles at this position, excluding the one that led to contradiction
		var possible_tiles = _get_possible_tiles(pos)
		possible_tiles.erase(rejected_tile)
		
		if possible_tiles.size() > 0:
			# We found an alternative! Mark this tile as impossible and continue
			_set_tile_possible(pos, rejected_tile, false)
			print("✅ BACKTRACK SUCCESS: At %s, removed tile %d, trying %d alternatives" % [pos, rejected_tile, possible_tiles.size()])
			return true
	
	print("❌ BACKTRACK EXHAUSTED: No alternatives found in %d placements" % placement_history.size())
	return false

func _restore_state(history_entry: Dictionary):
	"""Restore WFC state from a history entry"""
	var pos = history_entry.position
	
	# Restore tile array
	tile_array[pos.y][pos.x] = 0
	
	# Restore possibility array  
	possibility_array = history_entry.previous_possibilities
	
	# Restore undecided positions
	undecided_positions = history_entry.previous_undecided
	
	# Restore counters
	completed_tiles = history_entry.previous_completed_tiles
	
	# Mark entropy as dirty for all positions (since we restored possibilities)
	for y in range(map_height):
		for x in range(map_width):
			_mark_entropy_dirty(Vector2i(x, y))
	
	print("🔙 RESTORED: State to before placing tile at %s (completed: %d)" % [pos, completed_tiles])
