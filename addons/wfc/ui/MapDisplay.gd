extends Node2D
class_name MapDisplay

signal stats_updated(text: String)
signal current_tile_changed(text: String)
signal probabilities_changed(probabilities: Dictionary)

# Core properties
var map_width: int = 14
var map_height: int = 14
var tile_size: int = 16
var display_size: int = 32
var current_tileset: String = ""

# Visual properties
var show_borders: bool = true
var current_scale: float = 1.0
var min_scale: float = 1.0
var max_scale: float = 20.0

# WFC Integration
var wfc: WFC
var tileset_data: TilesetData
var tile_sprites: Array = []

# UI state
var continuous_generation: bool = false
var generation_counter: int = 0
var cursor_position: Vector2i = Vector2i.ZERO

# Cursor references
@onready var map_cursor: Node2D = $MapCursor

# Camera control
var camera: Camera2D

# Auto-scroll system
var auto_scroll_timer: Timer
var auto_scroll_directions: Dictionary = {}  # Track which keys are held
var auto_scroll_rate: float = 0.05  # 20 times per second (1/20 = 0.05)

func _ready():
	# Create camera
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)
	
	# Set up auto-scroll timer
	auto_scroll_timer = Timer.new()
	auto_scroll_timer.wait_time = auto_scroll_rate
	auto_scroll_timer.timeout.connect(_on_auto_scroll_timeout)
	add_child(auto_scroll_timer)
	
	# Set up initial scale
	scale = Vector2(current_scale, current_scale)

func initialize(width: int, height: int, tile_sz: int, tileset: String):
	map_width = width
	map_height = height
	tile_size = tile_sz
	current_tileset = tileset
	
	# Initialize visual grid
	_create_visual_grid()
	
	# Center camera on map
	camera.position = Vector2(map_width * display_size / 2, map_height * display_size / 2)
	
	# Initialize WFC
	_initialize_wfc()
	
	# Initialize cursor
	_initialize_cursor()
	
	# Load tileset if provided
	if tileset != "":
		load_tileset(tileset)

func _initialize_wfc():
	"""Initialize the WFC algorithm with test tileset"""
	# Create test tileset
	tileset_data = TilesetData.create_test_tileset()
	
	# Create WFC instance
	wfc = WFC.new()
	if wfc.initialize(map_width, map_height, tileset_data):
		# Connect WFC signals
		wfc.tile_placed.connect(_on_tile_placed)
		wfc.generation_complete.connect(_on_generation_complete)
		wfc.contradiction_found.connect(_on_contradiction_found)
		wfc.entropy_updated.connect(_on_entropy_updated)
		
		stats_updated.emit("WFC initialized with test tileset")
	else:
		stats_updated.emit("Failed to initialize WFC")

func _initialize_cursor():
	"""Initialize cursor system"""
	cursor_position = Vector2i(map_width / 2, map_height / 2)
	if map_cursor:
		map_cursor.initialize(map_width, map_height, display_size)
		map_cursor.move_to(cursor_position)
	_update_cursor_info()

func _create_visual_grid():
	# Clear existing sprites
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	
	# Initialize 2D tile_sprites array
	tile_sprites.clear()
	for y in range(map_height):
		tile_sprites.append([])  # Create row array first
	
	# Create sprite for each tile position
	for y in range(map_height):
		for x in range(map_width):
			var sprite = Sprite2D.new()
			sprite.position = Vector2(x * display_size + display_size/2, y * display_size + display_size/2)
			sprite.scale = Vector2(float(display_size) / tile_size, float(display_size) / tile_size)
			add_child(sprite)
			tile_sprites[y].append(sprite)  # Append to the row array
			
			# Add border if enabled
			if show_borders:
				_add_border_to_sprite(sprite)

func _add_border_to_sprite(sprite: Sprite2D):
	var border = ReferenceRect.new()
	border.position = -Vector2(display_size/2, display_size/2)
	border.size = Vector2(display_size, display_size)
	border.border_color = Color(0.3, 0.3, 0.3, 0.5)
	border.border_width = 1
	sprite.add_child(border)

func load_tileset(path: String):
	current_tileset = path
	# TODO: Load actual tileset data
	print("Loading tileset: ", path)
	stats_updated.emit("Tileset loaded: " + path.get_file())

func generate_tiles(count: int):
	if not wfc:
		stats_updated.emit("WFC not initialized")
		return
	
	generation_counter = count
	print("Generating ", count, " tiles using WFC")
	
	# Generate the requested number of tiles
	for i in range(count):
		if not wfc.generate_step():
			break  # Generation complete or contradiction
	
	# Update UI with current stats
	_update_stats_display()

func set_continuous_generation(enabled: bool):
	continuous_generation = enabled
	if enabled:
		# Start continuous generation timer
		var timer = Timer.new()
		timer.wait_time = 0.01  # 10ms intervals like original
		timer.timeout.connect(_continuous_generation_step)
		timer.autostart = true
		add_child(timer)
		stats_updated.emit("Continuous generation enabled")
	else:
		# Stop continuous generation
		for child in get_children():
			if child is Timer:
				child.queue_free()
		stats_updated.emit("Continuous generation disabled")

func _continuous_generation_step():
	if wfc and continuous_generation:
		if not wfc.generate_step():
			set_continuous_generation(false)  # Stop if complete or contradiction

func reset_map():
	if wfc:
		wfc.initialize(map_width, map_height, tileset_data)
		_update_all_tiles()
		stats_updated.emit("Map reset")
	else:
		stats_updated.emit("Cannot reset: WFC not initialized")

func toggle_borders():
	show_borders = not show_borders
	
	# Update all sprites
	for y in range(map_height):
		for x in range(map_width):
			var sprite = tile_sprites[y][x]
			if sprite:
				# Remove existing borders
				for child in sprite.get_children():
					if child is ReferenceRect:
						child.queue_free()
				
				# Add border if enabled
				if show_borders:
					_add_border_to_sprite(sprite)

func change_map_size(width: int, height: int, tile_sz: int):
	map_width = width
	map_height = height
	tile_size = tile_sz
	
	_create_visual_grid()
	_initialize_wfc()
	_initialize_cursor()  # Re-center cursor for new map size
	
	stats_updated.emit("Map size changed to " + str(width) + "x" + str(height))

func print_stats():
	print("=== WFC Statistics ===")
	print("Map size: ", map_width, "x", map_height)
	print("Tile size: ", tile_size)
	print("Current tileset: ", current_tileset)
	print("Continuous generation: ", continuous_generation)
	
	if wfc:
		var stats = wfc.get_stats()
		print("WFC Stats:")
		print("  Attempts: ", stats.attempts)
		print("  Contradictions: ", stats.contradictions)
		print("  Completed tiles: ", stats.completed_tiles)
		print("  Undecided positions: ", stats.undecided_positions)
		print("  Completion: %.1f%%" % stats.completion_percentage)
		print("  Lowest entropy: ", stats.lowest_entropy)
	
	if tileset_data:
		print("Tileset: %d tiles loaded" % tileset_data.get_non_blank_tile_ids().size())

# WFC Signal Handlers
func _on_tile_placed(position: Vector2i, tile_id: int):
	"""Called when WFC places a tile"""
	_update_tile_visual(position.x, position.y)

func _on_generation_complete():
	"""Called when WFC generation completes"""
	stats_updated.emit("Generation complete!")
	set_continuous_generation(false)

func _on_contradiction_found(position: Vector2i):
	"""Called when WFC encounters a contradiction"""
	stats_updated.emit("Contradiction found at (%d, %d)" % [position.x, position.y])
	set_continuous_generation(false)

func _on_entropy_updated(position: Vector2i, entropy: int):
	"""Called when lowest entropy is updated"""
	if position != Vector2i(-1, -1):
		stats_updated.emit("Lowest Entropy|(%d, %d): %d" % [position.x, position.y, entropy])

func place_tile(x: int, y: int, tile_id: int):
	"""Legacy method for manual tile placement"""
	if wfc:
		wfc.place_tile(Vector2i(x, y), tile_id)

func _update_tile_visual(x: int, y: int):
	if not wfc or x < 0 or x >= map_width or y < 0 or y >= map_height:
		return
	
	var tile_id = wfc.get_tile_at(Vector2i(x, y))
	var sprite = tile_sprites[y][x]
	
	if sprite and tile_id in tileset_data.tile_textures:
		sprite.texture = tileset_data.tile_textures[tile_id]

func _update_stats_display():
	"""Update the stats display with current WFC information"""
	if wfc:
		var stats = wfc.get_stats()
		var completion = "%.1f%%" % stats.completion_percentage
		stats_updated.emit("Completion: %s | Attempts: %d | Contradictions: %d" % [completion, stats.attempts, stats.contradictions])

func _update_all_tiles():
	for y in range(map_height):
		for x in range(map_width):
			_update_tile_visual(x, y)

# Consolidated Input Handling
func _input(event: InputEvent):
	# Handle zoom
	if event.is_action_pressed("zoom_in"):
		current_scale = min(current_scale + 0.5, max_scale)
		scale = Vector2(current_scale, current_scale)
	elif event.is_action_pressed("zoom_out"):
		current_scale = max(current_scale - 0.5, min_scale)
		scale = Vector2(current_scale, current_scale)
	
	# Handle all cursor input
	var old_pos = cursor_position
	var new_pos = cursor_position
	var is_keyboard_input = false
	var should_update_cursor = false
	
	if event is InputEventKey:
		# Handle auto-scroll key tracking
		_handle_auto_scroll_keys(event)
		
		# Handle immediate key press
		new_pos = _handle_keyboard_cursor(event)
		is_keyboard_input = true
		should_update_cursor = true
	elif event is InputEventMouseMotion:
		# Check for edge panning first
		var camera_moved = _check_mouse_edge_panning(event.position)
		
		# Only update cursor if mouse is within tilemap bounds
		if _is_mouse_in_tilemap():
			new_pos = _mouse_to_grid_position(event.position)
			should_update_cursor = true
		elif camera_moved:
			# If camera moved due to edge panning, update cursor to follow
			new_pos = _get_cursor_for_current_camera()
			should_update_cursor = true
	elif event is InputEventMouseButton and event.pressed:
		# Only update cursor if mouse is within tilemap bounds
		if _is_mouse_in_tilemap():
			new_pos = _mouse_to_grid_position(event.position)
			should_update_cursor = true
			if event.double_click:
				_on_tile_double_clicked(new_pos)
	
	if should_update_cursor and new_pos != old_pos:
		_update_cursor_position(new_pos, is_keyboard_input)  # Camera follows only on keyboard input

func _handle_keyboard_cursor(event: InputEvent) -> Vector2i:
	"""Handle keyboard cursor movement"""
	var new_pos = cursor_position
	
	if event.is_action_pressed("cursor_up"):
		new_pos.y = max(0, cursor_position.y - 1)
	elif event.is_action_pressed("cursor_down"):
		new_pos.y = min(map_height - 1, cursor_position.y + 1)
	elif event.is_action_pressed("cursor_left"):
		new_pos.x = max(0, cursor_position.x - 1)
	elif event.is_action_pressed("cursor_right"):
		new_pos.x = min(map_width - 1, cursor_position.x + 1)
	
	return new_pos

func _mouse_to_grid_position(mouse_pos: Vector2) -> Vector2i:
	"""Convert mouse position to grid coordinates"""
	if not camera:
		return Vector2i.ZERO
		
	var viewport = get_viewport()
	if not viewport:
		return Vector2i.ZERO
	
	# Get viewport size and mouse position relative to viewport
	var viewport_size = viewport.get_visible_rect().size
	var mouse_viewport_pos = mouse_pos
	
	# Convert viewport mouse position to world coordinates
	# Account for camera position and current scale
	var viewport_center = viewport_size / 2
	var mouse_offset_from_center = mouse_viewport_pos - viewport_center
	var world_offset = mouse_offset_from_center / current_scale
	var world_pos = camera.position + world_offset
	
	# Convert world coordinates to grid coordinates
	var grid_x = int(world_pos.x / display_size)
	var grid_y = int(world_pos.y / display_size)
	
	# Clamp to valid range
	grid_x = clamp(grid_x, 0, map_width - 1)
	grid_y = clamp(grid_y, 0, map_height - 1)
	
	return Vector2i(grid_x, grid_y)

func _is_mouse_in_tilemap() -> bool:
	"""Check if mouse is within the tilemap bounds"""
	if not camera:
		return false
		
	var viewport = get_viewport()
	if not viewport:
		return false
	
	# Get mouse position in screen coordinates
	var mouse_pos = viewport.get_mouse_position()
	
	# Convert to world coordinates using the same method as _mouse_to_grid_position
	var viewport_size = viewport.get_visible_rect().size
	var viewport_center = viewport_size / 2
	var mouse_offset_from_center = mouse_pos - viewport_center
	var world_offset = mouse_offset_from_center / current_scale
	var world_pos = camera.position + world_offset
	
	# Check if within tilemap bounds in world coordinates
	var map_size_pixels = Vector2(map_width * display_size, map_height * display_size)
	return world_pos.x >= 0 and world_pos.x < map_size_pixels.x and world_pos.y >= 0 and world_pos.y < map_size_pixels.y

func _update_cursor_position(new_pos: Vector2i, move_camera: bool = false):
	"""Update cursor position - single source of truth"""
	cursor_position = new_pos
	
	# Update visual cursor
	if map_cursor:
		map_cursor.move_to(cursor_position)
	
	# Phase 1: Simple camera following - only on keyboard input
	if move_camera:
		_update_camera_simple()
	
	# Update UI info
	_update_cursor_info()

func _on_tile_double_clicked(pos: Vector2i):
	"""Handle double-click on tile"""
	print("Double-clicked tile at (%d, %d)" % [pos.x, pos.y])
	# TODO: Add tile selection/inspection logic

func _update_cursor_info():
	if wfc:
		var tile_id = wfc.get_tile_at(cursor_position)
		var entropy = wfc.get_entropy_at(cursor_position)
		current_tile_changed.emit("Position: (%d, %d) | Tile: %d | Entropy: %d" % [cursor_position.x, cursor_position.y, tile_id, entropy])
		
		# Get actual probabilities at cursor position
		var probabilities = wfc.get_probabilities_at(cursor_position)
		probabilities_changed.emit(probabilities)
	else:
		current_tile_changed.emit("Position: (%d, %d) | WFC not initialized" % [cursor_position.x, cursor_position.y])

# Phase 1: Edge-Based Camera Following

func _update_camera_simple():
	"""Phase 1: Move camera only when cursor is at edge of visible area"""
	if not camera:
		return
	
	# Get current viewport size and calculate visible area
	var viewport = get_viewport()
	if not viewport:
		return
		
	var viewport_size = viewport.get_visible_rect().size
	var visible_area_world = viewport_size / current_scale
	
	# Calculate current camera bounds in world coordinates
	var camera_top_left = camera.position - visible_area_world / 2
	var camera_bottom_right = camera.position + visible_area_world / 2
	
	# Convert cursor to world coordinates (center of tile)
	var cursor_world = Vector2(cursor_position) * display_size + Vector2(display_size/2, display_size/2)
	
	# Check if cursor is near edges and calculate needed camera adjustment
	var camera_offset = Vector2.ZERO
	var edge_margin = display_size * 2  # 2 tiles from edge
	
	# Check each edge
	if cursor_world.x < camera_top_left.x + edge_margin:
		# Cursor near left edge
		camera_offset.x = cursor_world.x - edge_margin - camera_top_left.x
	elif cursor_world.x > camera_bottom_right.x - edge_margin:
		# Cursor near right edge
		camera_offset.x = cursor_world.x + edge_margin - camera_bottom_right.x
		
	if cursor_world.y < camera_top_left.y + edge_margin:
		# Cursor near top edge
		camera_offset.y = cursor_world.y - edge_margin - camera_top_left.y
	elif cursor_world.y > camera_bottom_right.y - edge_margin:
		# Cursor near bottom edge
		camera_offset.y = cursor_world.y + edge_margin - camera_bottom_right.y
	
	# Only move camera if there's an offset needed
	if camera_offset != Vector2.ZERO:
		camera.position += camera_offset

func _check_mouse_edge_panning(mouse_screen_pos: Vector2) -> bool:
	"""Check if mouse is at screen edge and pan camera accordingly"""
	if not camera:
		return false
		
	var viewport = get_viewport()
	if not viewport:
		return false
		
	var viewport_size = viewport.get_visible_rect().size
	var edge_threshold = 50  # pixels from screen edge to trigger panning
	var pan_speed = 5.0  # pixels per frame to pan
	
	var camera_offset = Vector2.ZERO
	
	# Check screen edges (not tilemap edges)
	if mouse_screen_pos.x < edge_threshold:
		# Mouse near left edge of screen
		camera_offset.x = -pan_speed
	elif mouse_screen_pos.x > viewport_size.x - edge_threshold:
		# Mouse near right edge of screen  
		camera_offset.x = pan_speed
		
	if mouse_screen_pos.y < edge_threshold:
		# Mouse near top edge of screen
		camera_offset.y = -pan_speed
	elif mouse_screen_pos.y > viewport_size.y - edge_threshold:
		# Mouse near bottom edge of screen
		camera_offset.y = pan_speed
	
	# Apply panning if needed
	if camera_offset != Vector2.ZERO:
		# Adjust for current scale
		camera_offset = camera_offset / current_scale
		camera.position += camera_offset
		return true
		
	return false

func _get_cursor_for_current_camera() -> Vector2i:
	"""Get appropriate cursor position for current camera center"""
	var viewport = get_viewport()
	if not viewport:
		return cursor_position
		
	# Get camera center in world coordinates
	var camera_center = camera.position
	
	# Convert to grid coordinates
	var grid_pos = camera_center / display_size
	var cursor_grid = Vector2i(int(grid_pos.x), int(grid_pos.y))
	
	# Clamp to map bounds
	cursor_grid.x = clamp(cursor_grid.x, 0, map_width - 1)
	cursor_grid.y = clamp(cursor_grid.y, 0, map_height - 1)
	
	return cursor_grid

# Auto-scroll System

func _handle_auto_scroll_keys(event: InputEvent):
	"""Track which cursor keys are currently held down"""
	if event is InputEventKey:
		var action_name = ""
		
		# Map keyboard events to direction names
		if event.is_action("cursor_up"):
			action_name = "up"
		elif event.is_action("cursor_down"):
			action_name = "down"
		elif event.is_action("cursor_left"):
			action_name = "left"
		elif event.is_action("cursor_right"):
			action_name = "right"
		
		if action_name != "":
			if event.pressed:
				# Key pressed - start tracking
				auto_scroll_directions[action_name] = true
				_update_auto_scroll_timer()
			else:
				# Key released - stop tracking
				auto_scroll_directions.erase(action_name)
				_update_auto_scroll_timer()

func _update_auto_scroll_timer():
	"""Start or stop the auto-scroll timer based on held keys"""
	if auto_scroll_timer == null:
		return
	
	if auto_scroll_directions.size() > 0:
		# Keys are held - start timer if not already running
		if auto_scroll_timer.is_stopped():
			auto_scroll_timer.start()
	else:
		# No keys held - stop timer
		auto_scroll_timer.stop()

func _on_auto_scroll_timeout():
	"""Called every 0.05 seconds while keys are held to auto-move cursor"""
	if auto_scroll_directions.size() == 0:
		auto_scroll_timer.stop()
		return
	
	# Calculate movement based on held keys
	var movement = Vector2i.ZERO
	
	if auto_scroll_directions.has("up"):
		movement.y -= 1
	if auto_scroll_directions.has("down"):
		movement.y += 1
	if auto_scroll_directions.has("left"):
		movement.x -= 1
	if auto_scroll_directions.has("right"):
		movement.x += 1
	
	# Apply movement
	if movement != Vector2i.ZERO:
		var new_pos = cursor_position + movement
		
		# Clamp to map bounds
		new_pos.x = clamp(new_pos.x, 0, map_width - 1)
		new_pos.y = clamp(new_pos.y, 0, map_height - 1)
		
		# Update cursor with camera following
		if new_pos != cursor_position:
			_update_cursor_position(new_pos, true)  # true for camera following
