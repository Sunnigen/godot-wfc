extends RefCounted
class_name TilemapAnalyzer

# Core analysis data
var tilemap_image: Image
var tile_size: int
var map_width: int
var map_height: int
var output_name: String

# Analysis results
var unique_tiles: Array[Image] = []
var tile_positions: Dictionary = {}  # tile_id -> Array[Vector2i] positions
var adjacency_map: Dictionary = {}   # position -> {N, E, S, W: tile_id}
var tileset_data: TilesetData

# Adjacency method parameters
var color_threshold: float = 25.0
var use_position_rules: bool = true
var use_pixel_rules: bool = true

# Progress tracking
signal progress_updated(step: String, percentage: float)
signal analysis_complete(tileset: TilesetData)
signal analysis_failed(error: String)

func _init():
	pass

func analyze_tilemap(file_path: String, tile_sz: int, output_nm: String, color_thresh: float = 25.0, use_pos_rules: bool = true, use_pix_rules: bool = true):
	"""Main entry point for tilemap analysis"""
	tile_size = tile_sz
	output_name = output_nm
	color_threshold = color_thresh
	use_position_rules = use_pos_rules
	use_pixel_rules = use_pix_rules
	
	progress_updated.emit("Cleaning up existing files...", 0.0)
	
	# Clean up any existing files for this tileset
	_cleanup_existing_files()
	
	progress_updated.emit("Loading tilemap image...", 5.0)
	
	# Step 1: Load and validate the tilemap
	if not _load_tilemap(file_path):
		analysis_failed.emit("Failed to load tilemap: " + file_path)
		return
	
	progress_updated.emit("Extracting tiles...", 25.0)
	
	# Step 2: Extract individual tiles
	if not _extract_tiles():
		analysis_failed.emit("Failed to extract tiles from tilemap")
		return
	
	progress_updated.emit("Analyzing adjacency patterns...", 50.0)
	
	# Step 3: Analyze adjacency patterns
	if not _analyze_adjacency_patterns():
		analysis_failed.emit("Failed to analyze adjacency patterns")
		return
	
	progress_updated.emit("Generating tileset rules...", 75.0)
	
	# Step 4: Generate tileset data
	if not _generate_tileset_data():
		analysis_failed.emit("Failed to generate tileset data")
		return
	
	progress_updated.emit("Saving tileset...", 90.0)
	
	# Step 5: Save the tileset
	if not _save_tileset():
		analysis_failed.emit("Failed to save tileset")
		return
	
	progress_updated.emit("Analysis complete!", 100.0)
	analysis_complete.emit(tileset_data)

func _load_tilemap(file_path: String) -> bool:
	"""Load and validate the tilemap image"""
	if not FileAccess.file_exists(file_path):
		push_error("TilemapAnalyzer: File does not exist: " + file_path)
		return false
	
	tilemap_image = Image.new()
	var error = tilemap_image.load(file_path)
	
	if error != OK:
		push_error("TilemapAnalyzer: Failed to load image: " + str(error))
		return false
	
	# Validate dimensions
	if tilemap_image.get_width() % tile_size != 0 or tilemap_image.get_height() % tile_size != 0:
		push_error("TilemapAnalyzer: Image dimensions not divisible by tile size")
		push_error("  Image: %dx%d, Tile size: %d" % [tilemap_image.get_width(), tilemap_image.get_height(), tile_size])
		return false
	
	map_width = tilemap_image.get_width() / tile_size
	map_height = tilemap_image.get_height() / tile_size
	
	print("TilemapAnalyzer: Loaded tilemap %dx%d pixels, %dx%d tiles" % [tilemap_image.get_width(), tilemap_image.get_height(), map_width, map_height])
	return true

func _extract_tiles() -> bool:
	"""Extract individual tiles and identify unique ones"""
	if not tilemap_image:
		return false
	
	unique_tiles.clear()
	tile_positions.clear()
	
	var tile_id_counter = 1  # Start from 1 (0 reserved for blank)
	var tile_cache: Dictionary = {}  # hash -> tile_id for deduplication
	
	# Process each tile position
	for y in range(map_height):
		for x in range(map_width):
			# Extract tile image
			var tile_image = _extract_tile_at(x, y)
			if not tile_image:
				continue
			
			# Calculate hash for deduplication
			var tile_hash = _calculate_tile_hash(tile_image)
			var tile_id: int
			
			if tile_hash in tile_cache:
				# This tile already exists
				tile_id = tile_cache[tile_hash]
			else:
				# New unique tile
				tile_id = tile_id_counter
				tile_id_counter += 1
				
				unique_tiles.append(tile_image)
				tile_cache[tile_hash] = tile_id
				tile_positions[tile_id] = []
			
			# Record this position for the tile
			tile_positions[tile_id].append(Vector2i(x, y))
	
	print("TilemapAnalyzer: Found %d unique tiles from %d total positions" % [unique_tiles.size(), map_width * map_height])
	return unique_tiles.size() > 0

func _extract_tile_at(tile_x: int, tile_y: int) -> Image:
	"""Extract a single tile image at the given tile coordinates"""
	var pixel_x = tile_x * tile_size
	var pixel_y = tile_y * tile_size
	
	var tile_image = Image.create(tile_size, tile_size, false, tilemap_image.get_format())
	
	# Copy pixels from source to tile
	for y in range(tile_size):
		for x in range(tile_size):
			var source_x = pixel_x + x
			var source_y = pixel_y + y
			
			if source_x < tilemap_image.get_width() and source_y < tilemap_image.get_height():
				var pixel = tilemap_image.get_pixel(source_x, source_y)
				tile_image.set_pixel(x, y, pixel)
	
	return tile_image

func _calculate_tile_hash(tile_image: Image) -> String:
	"""Calculate a hash for tile deduplication - examining every pixel"""
	var hash_string = ""
	
	# Check EVERY pixel for exact duplicate detection
	for y in range(tile_size):
		for x in range(tile_size):
			var pixel = tile_image.get_pixel(x, y)
			# Create exact color signature for each pixel
			hash_string += str(int(pixel.r * 255)) + "_" + str(int(pixel.g * 255)) + "_" + str(int(pixel.b * 255)) + "|"
	
	return hash_string

func _analyze_adjacency_patterns() -> bool:
	"""Analyze which tiles are adjacent to each other"""
	adjacency_map.clear()
	
	# For each position in the original tilemap, record its neighbors
	for tile_id in tile_positions.keys():
		var positions = tile_positions[tile_id]
		
		for pos in positions:
			if not adjacency_map.has(pos):
				adjacency_map[pos] = {}
			
			# Check all four directions
			var directions = {
				"N": Vector2i(0, -1),  # North
				"E": Vector2i(1, 0),   # East  
				"S": Vector2i(0, 1),   # South
				"W": Vector2i(-1, 0)   # West
			}
			
			for dir_name in directions.keys():
				var neighbor_pos = pos + directions[dir_name]
				var neighbor_tile_id = _get_tile_id_at_position(neighbor_pos)
				
				adjacency_map[pos][dir_name] = neighbor_tile_id
	
	print("TilemapAnalyzer: Analyzed adjacency patterns for %d positions" % adjacency_map.size())
	return true

func _get_tile_id_at_position(pos: Vector2i) -> int:
	"""Get the tile ID at a specific position, or 0 if out of bounds"""
	if pos.x < 0 or pos.x >= map_width or pos.y < 0 or pos.y >= map_height:
		return 0  # Out of bounds = blank tile
	
	# Find which tile is at this position
	for tile_id in tile_positions.keys():
		var positions = tile_positions[tile_id]
		if pos in positions:
			return tile_id
	
	return 0  # Should not happen

func _generate_tileset_data() -> bool:
	"""Generate TilesetData from the analysis results"""
	tileset_data = TilesetData.new()
	tileset_data.tile_size = tile_size
	
	# Create adjacency rules by aggregating patterns
	var tile_rules: Dictionary = {}  # tile_id -> {N: Set, E: Set, S: Set, W: Set}
	
	# Initialize rule sets for each tile
	for tile_id in range(1, unique_tiles.size() + 1):
		tile_rules[tile_id] = {
			"N": {},  # Use dictionaries as sets
			"E": {},
			"S": {},
			"W": {}
		}
	
	# First pass: collect position-based adjacency relationships (if enabled)
	if use_position_rules:
		print("TilemapAnalyzer: Generating position-based adjacencies")
		for pos in adjacency_map.keys():
			var center_tile_id = _get_tile_id_at_position(pos)
			if center_tile_id == 0:
				continue
			
			var neighbors = adjacency_map[pos]
			for direction in ["N", "E", "S", "W"]:
				var neighbor_id = neighbors.get(direction, 0)
				if neighbor_id > 0:  # Valid neighbor
					tile_rules[center_tile_id][direction][neighbor_id] = true
		
		# Second pass: ensure bidirectional symmetry for position-based rules
		for tile_id in tile_rules.keys():
			for direction in ["N", "E", "S", "W"]:
				var neighbors_in_direction = tile_rules[tile_id][direction].keys()
				var opposite_dir = _get_opposite_direction(direction)
				
				for neighbor_id in neighbors_in_direction:
					# Ensure the reverse relationship exists
					if neighbor_id in tile_rules:
						tile_rules[neighbor_id][opposite_dir][tile_id] = true
	else:
		print("TilemapAnalyzer: Skipping position-based adjacencies (disabled)")
	
	# Count position-based adjacencies before adding pixel-based ones
	var position_based_adjacencies = 0
	for tile_id in tile_rules.keys():
		for direction in ["N", "E", "S", "W"]:
			position_based_adjacencies += tile_rules[tile_id][direction].size()
	
	# Third pass: add pixel-based adjacencies (if enabled)
	var pixel_based_adjacencies = 0
	var pixel_comparisons = 0
	
	print("TilemapAnalyzer: Starting with %d position-based adjacencies" % position_based_adjacencies)
	
	if use_pixel_rules:
		print("TilemapAnalyzer: Adding pixel-based adjacencies (threshold: %d)" % color_threshold)
		
		for tile_a in range(1, unique_tiles.size() + 1):
			for tile_b in range(1, unique_tiles.size() + 1):
				if tile_a == tile_b:
					continue  # Skip self-comparison
				
				for direction in ["N", "E", "S", "W"]:
					pixel_comparisons += 1
					
					# Check if not already connected by position-based rules
					if not tile_rules[tile_a][direction].has(tile_b):
						# Test pixel compatibility
						if _tiles_compatible_by_color(tile_a, tile_b, direction):
							# Add bidirectional adjacency
							tile_rules[tile_a][direction][tile_b] = true
							var opposite_dir = _get_opposite_direction(direction)
							tile_rules[tile_b][opposite_dir][tile_a] = true
							pixel_based_adjacencies += 1
	else:
		print("TilemapAnalyzer: Skipping pixel-based adjacencies (disabled)")
	
	# Count total adjacencies after adding pixel-based ones
	var total_adjacencies = 0
	for tile_id in tile_rules.keys():
		for direction in ["N", "E", "S", "W"]:
			total_adjacencies += tile_rules[tile_id][direction].size()
	
	if use_pixel_rules:
		print("TilemapAnalyzer: Added %d pixel-based adjacencies from %d comparisons" % [pixel_based_adjacencies, pixel_comparisons])
	
	var methods_used = []
	if use_position_rules:
		methods_used.append("position")
	if use_pixel_rules:
		methods_used.append("pixel")
	
	print("TilemapAnalyzer: Final result: %d total adjacencies using %s methods" % [total_adjacencies, "/".join(methods_used)])
	if use_position_rules and use_pixel_rules:
		print("  ├─ Position-based: %d" % position_based_adjacencies)
		print("  └─ Pixel-based: %d" % (total_adjacencies - position_based_adjacencies))
	
	# Convert to TilesetData format and add tiles
	for tile_id in range(1, unique_tiles.size() + 1):
		var tile_image = unique_tiles[tile_id - 1]
		var texture = ImageTexture.create_from_image(tile_image)
		
		# Convert rule sets to arrays for TilesetData
		var adjacent_tiles = [
			tile_rules[tile_id]["S"].keys(),  # South
			tile_rules[tile_id]["E"].keys(),  # East
			tile_rules[tile_id]["N"].keys(),  # North
			tile_rules[tile_id]["W"].keys()   # West
		]
		
		var probabilities = [1.0, 1.0, 1.0, 1.0]  # Equal probability in all directions
		tileset_data.add_tile(tile_id, texture, adjacent_tiles, probabilities)
	
	print("TilemapAnalyzer: Generated tileset with %d tiles" % unique_tiles.size())
	return tileset_data.validate()

func _save_tileset() -> bool:
	"""Save the tileset to files"""
	if not tileset_data:
		return false
	
	# Save individual tile images
	var tiles_dir = "res://data/extracted_tiles/" + output_name
	if not _create_directory(tiles_dir):
		push_error("Failed to create tiles directory: " + tiles_dir)
		return false
	
	# Save each tile image
	for i in range(unique_tiles.size()):
		var tile_image = unique_tiles[i]
		var tile_path = tiles_dir + "/tile_%02d.png" % (i + 1)
		var abs_path = ProjectSettings.globalize_path(tile_path)
		
		var error = tile_image.save_png(abs_path)
		if error != OK:
			push_error("Failed to save tile image: " + tile_path)
			return false
	
	# Save tileset resource
	var tileset_path = "res://data/generated_tilesets/" + output_name + ".tres"
	var error = ResourceSaver.save(tileset_data, tileset_path)
	
	if error != OK:
		push_error("Failed to save tileset resource: " + tileset_path)
		return false
	
	print("TilemapAnalyzer: Saved tileset to " + tileset_path)
	print("TilemapAnalyzer: Saved %d tile images to " + tiles_dir)
	return true

func _create_directory(path: String) -> bool:
	"""Create directory if it doesn't exist"""
	var abs_path = ProjectSettings.globalize_path(path)
	var dir = DirAccess.open(ProjectSettings.globalize_path("res://"))
	
	if not dir:
		return false
	
	# Create nested directories
	var parts = path.replace("res://", "").split("/")
	var current_path = ProjectSettings.globalize_path("res://")
	
	for part in parts:
		if part.is_empty():
			continue
		current_path = current_path.path_join(part)
		if not DirAccess.dir_exists_absolute(current_path):
			var make_error = dir.make_dir_recursive(current_path.replace(ProjectSettings.globalize_path("res://"), ""))
			if make_error != OK:
				return false
	
	return true

func _get_opposite_direction(direction: String) -> String:
	"""Get the opposite direction for bidirectional adjacency"""
	match direction:
		"N": return "S"
		"S": return "N"
		"E": return "W"
		"W": return "E"
		_: return "N"  # Default fallback

# Pixel-based adjacency methods

func _get_edge_pixels(tile_image: Image, direction: String) -> Array[Color]:
	"""Extract all edge pixels for a given direction"""
	var edge_pixels: Array[Color] = []
	var size = tile_image.get_width()  # Assuming square tiles
	
	match direction:
		"N":  # North - top row
			for x in range(size):
				edge_pixels.append(tile_image.get_pixel(x, 0))
		"S":  # South - bottom row
			for x in range(size):
				edge_pixels.append(tile_image.get_pixel(x, size - 1))
		"E":  # East - right column
			for y in range(size):
				edge_pixels.append(tile_image.get_pixel(size - 1, y))
		"W":  # West - left column
			for y in range(size):
				edge_pixels.append(tile_image.get_pixel(0, y))
	
	return edge_pixels

func _rgb_distance(color1: Color, color2: Color) -> float:
	"""Calculate RGB distance between two colors"""
	var dr = abs(color1.r - color2.r) * 255.0
	var dg = abs(color1.g - color2.g) * 255.0
	var db = abs(color1.b - color2.b) * 255.0
	# Use max difference (Chebyshev distance) for strict color matching
	return max(dr, max(dg, db))

func _tiles_compatible_by_color(tile_a_id: int, tile_b_id: int, direction: String) -> bool:
	"""Check if two tiles are compatible based on edge color similarity"""
	if tile_a_id < 1 or tile_a_id > unique_tiles.size() or tile_b_id < 1 or tile_b_id > unique_tiles.size():
		return false
	
	var tile_a_image = unique_tiles[tile_a_id - 1]  # tile_id is 1-based, array is 0-based
	var tile_b_image = unique_tiles[tile_b_id - 1]
	
	# Get the appropriate edges for comparison
	var tile_a_edge = _get_edge_pixels(tile_a_image, direction)
	var opposite_direction = _get_opposite_direction(direction)
	var tile_b_edge = _get_edge_pixels(tile_b_image, opposite_direction)
	
	# Both edges must have the same number of pixels
	if tile_a_edge.size() != tile_b_edge.size():
		return false
	
	# Check if ALL edge pixels are within threshold
	for i in range(tile_a_edge.size()):
		var color_distance = _rgb_distance(tile_a_edge[i], tile_b_edge[i])
		if color_distance > color_threshold:
			return false  # One pixel exceeds threshold, tiles incompatible
	
	return true  # All pixels within threshold

func _cleanup_existing_files():
	"""Remove existing tileset and tile images before re-analysis"""
	# Clean up the .tres file
	var tileset_path = "res://data/generated_tilesets/" + output_name + ".tres"
	if FileAccess.file_exists(tileset_path):
		var abs_path = ProjectSettings.globalize_path(tileset_path)
		DirAccess.remove_absolute(abs_path)
		print("TilemapAnalyzer: Removed existing tileset: " + tileset_path)
	
	# Clean up the extracted tiles directory
	var tiles_dir = "res://data/extracted_tiles/" + output_name
	var abs_tiles_dir = ProjectSettings.globalize_path(tiles_dir)
	
	if DirAccess.dir_exists_absolute(abs_tiles_dir):
		# Remove all files in the directory
		var dir = DirAccess.open(abs_tiles_dir)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			
			# Remove the directory itself
			var parent_dir = DirAccess.open(ProjectSettings.globalize_path("res://data/extracted_tiles/"))
			if parent_dir:
				parent_dir.remove(output_name)
				print("TilemapAnalyzer: Removed existing tiles directory: " + tiles_dir)
