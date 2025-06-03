extends Window
class_name TileMatchesDialog

@onready var main_tile_preview: TextureRect = $VBox/MainTileContainer/TilePreview
@onready var main_tile_label: Label = $VBox/MainTileContainer/TileLabel
@onready var tile_selector: OptionButton = $VBox/MainTileContainer/TileSelector
@onready var matches_container: VBoxContainer = $VBox/ScrollContainer/MatchesContainer

var tile_textures: Dictionary = {}
var matching_tile_data: Dictionary = {}
var current_tile_id: int = -1

func _ready():
	title = "Tile Matches"
	size = Vector2i(600, 500)
	
	# Connect signals
	tile_selector.item_selected.connect(_on_tile_selected)

func show_matches(textures: Dictionary, matches_data: Dictionary):
	tile_textures = textures
	matching_tile_data = matches_data
	
	# Populate tile selector
	tile_selector.clear()
	var sorted_tiles = tile_textures.keys()
	sorted_tiles.sort()
	
	for tile_id in sorted_tiles:
		tile_selector.add_item("Tile %d" % tile_id, tile_id)
	
	# Select first tile
	if sorted_tiles.size() > 0:
		tile_selector.selected = 0
		_on_tile_selected(0)
	
	popup_centered()

func _on_tile_selected(index: int):
	current_tile_id = tile_selector.get_item_id(index)
	
	# Update main tile display
	main_tile_label.text = "Tile %d" % current_tile_id
	if current_tile_id in tile_textures:
		main_tile_preview.texture = tile_textures[current_tile_id]
	
	# Clear existing matches
	for child in matches_container.get_children():
		child.queue_free()
	
	# Display matches for each direction
	if current_tile_id in matching_tile_data:
		var directions = ["South", "East", "North", "West"]
		var matches = matching_tile_data[current_tile_id]
		
		for i in range(4):
			if i < matches.size():
				var direction_container = _create_direction_section(directions[i], matches[i])
				matches_container.add_child(direction_container)

func _create_direction_section(direction_name: String, matches: Dictionary) -> Control:
	var section = VBoxContainer.new()
	
	# Direction header
	var header = Label.new()
	header.text = "%s Matches:" % direction_name
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)
	
	# Matches grid
	var grid = HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	
	# Sort matches by probability
	var sorted_matches = []
	for tile_id in matches:
		sorted_matches.append([tile_id, matches[tile_id]])
	sorted_matches.sort_custom(func(a, b): return a[1] > b[1])
	
	# Create tile entries
	for match_data in sorted_matches:
		var tile_id = match_data[0]
		var probability = match_data[1]
		
		var tile_entry = _create_tile_entry(tile_id, probability)
		grid.add_child(tile_entry)
	
	section.add_child(grid)
	
	# Add separator
	var separator = HSeparator.new()
	section.add_child(separator)
	
	return section

func _create_tile_entry(tile_id: int, probability: float) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(64, 80)
	
	# Tile preview
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if tile_id in tile_textures:
		preview.texture = tile_textures[tile_id]
	
	# Center the preview
	var preview_container = CenterContainer.new()
	preview_container.add_child(preview)
	container.add_child(preview_container)
	
	# Tile info
	var info_label = Label.new()
	info_label.text = "Tile %d\n%.1f%%" % [tile_id, probability * 100]
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(info_label)
	
	return container
