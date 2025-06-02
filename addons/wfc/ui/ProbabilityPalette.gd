extends ScrollContainer
class_name ProbabilityPalette

@onready var tile_list: VBoxContainer = $Content/TileList

var tile_entries: Dictionary = {}
var tile_textures: Dictionary = {}

var scroll_horizontal_enabled: bool
var scroll_vertical_enabled: bool

func _ready():
	# Set up scrolling
	scroll_horizontal_enabled = false
	scroll_vertical_enabled = true

func initialize():
	# Clear existing entries
	for child in tile_list.get_children():
		child.queue_free()
	tile_entries.clear()

func update_probabilities(probabilities: Dictionary):
	# Clear existing entries
	for child in tile_list.get_children():
		child.queue_free()
	tile_entries.clear()
	
	# Sort by probability (highest first)
	var sorted_tiles = []
	for tile_id in probabilities:
		sorted_tiles.append([tile_id, probabilities[tile_id]])
	
	sorted_tiles.sort_custom(func(a, b): return a[1] > b[1])
	
	# Create entry for each tile
	for tile_data in sorted_tiles:
		var tile_id = tile_data[0]
		var probability = tile_data[1]
		
		var entry = _create_tile_entry(tile_id, probability)
		tile_list.add_child(entry)
		tile_entries[tile_id] = entry

func _create_tile_entry(tile_id: int, probability: float) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	
	# Tile preview
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set texture if available
	if tile_id in tile_textures:
		preview.texture = tile_textures[tile_id]
	else:
		# Placeholder
		preview.modulate = Color(0.5, 0.5, 0.5)
	
	# Tile info label
	var label = Label.new()
	label.text = "Tile %d: %.1f%%" % [tile_id, probability * 100]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Modify probability button
	var modify_btn = Button.new()
	modify_btn.text = "Modify"
	modify_btn.pressed.connect(_on_modify_pressed.bind(tile_id))
	
	container.add_child(preview)
	container.add_child(label)
	container.add_child(modify_btn)
	
	return container

func _on_modify_pressed(tile_id: int):
	# TODO: Show probability modification dialog
	print("Modify probability for tile ", tile_id)

func load_tile_textures(textures: Dictionary):
	tile_textures = textures
	# Update existing entries
	for tile_id in tile_entries:
		if tile_id in textures:
			var entry = tile_entries[tile_id]
			var preview = entry.get_child(0) as TextureRect
			if preview:
				preview.texture = textures[tile_id]

# Animation for showing/hiding palette
func show_palette():
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

func hide_palette():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): visible = false)
