extends Control

# UI References
@onready var map_viewport: SubViewport = $HSplitContainer/MapSection/ViewportContainer/SubViewport
@onready var map_display: Node2D = $HSplitContainer/MapSection/ViewportContainer/SubViewport/MapDisplay
@onready var probability_palette: Control = $HSplitContainer/ProbabilityPalette
@onready var generation_toggle: CheckBox = $HSplitContainer/MapSection/TopBar/GenerationToggle
@onready var stats_label: Label = $HSplitContainer/MapSection/BottomBar/StatsLabel
@onready var current_tile_label: Label = $HSplitContainer/MapSection/BottomBar/CurrentTileLabel
@onready var map_size_dialog: AcceptDialog = $MapSizeDialog
@onready var tileset_dialog: FileDialog = $TilesetDialog

# Settings
var map_width: int = 14
var map_height: int = 14
var tile_size: int = 16
var display_size: int = 32
var continuous_generation: bool = false
var generation_counter: int = 0

# Default tileset
var current_tileset: String = "flowers.pickle"

func _ready():
	# Connect UI signals
	tileset_dialog.file_selected.connect(_on_tileset_selected)
	
	# Set up file dialog
	tileset_dialog.current_dir = "res://data/"
	tileset_dialog.add_filter("*.pickle", "Pickle Tileset Files")
	
	# Initialize map display
	if map_display:
		map_display.initialize(map_width, map_height, tile_size, current_tileset)
		map_display.stats_updated.connect(_on_stats_updated)
		map_display.current_tile_changed.connect(_on_current_tile_changed)
		map_display.probabilities_changed.connect(_on_probabilities_changed)
	
	# Initialize probability palette
	if probability_palette:
		probability_palette.initialize()
	
	# Update initial UI state
	_update_ui_state()

func _on_generation_toggled(pressed: bool):
	continuous_generation = pressed
	if map_display:
		map_display.set_continuous_generation(pressed)

func _on_stats_updated(text: String):
	if stats_label:
		stats_label.text = text

func _on_current_tile_changed(text: String):
	if current_tile_label:
		current_tile_label.text = text

func _on_probabilities_changed(probabilities: Dictionary):
	if probability_palette:
		probability_palette.update_probabilities(probabilities)

func _on_tileset_selected(path: String):
	current_tileset = path
	if map_display:
		map_display.load_tileset(path)

func _on_generate_one_pressed():
	generation_counter = 1
	if map_display:
		map_display.generate_tiles(1)

func _on_generate_five_pressed():
	generation_counter = 5
	if map_display:
		map_display.generate_tiles(5)

func _on_reset_map_pressed():
	if map_display:
		map_display.reset_map()

func _on_toggle_border_pressed():
	if map_display:
		map_display.toggle_borders()

func _on_map_size_pressed():
	# Show map size dialog
	var width_input = map_size_dialog.get_node("VBox/GridContainer/WidthInput") as SpinBox
	var height_input = map_size_dialog.get_node("VBox/GridContainer/HeightInput") as SpinBox
	
	if width_input and height_input:
		width_input.value = map_width
		height_input.value = map_height
	
	map_size_dialog.popup_centered()

func _on_map_size_confirmed():
	var width_input = map_size_dialog.get_node("VBox/GridContainer/WidthInput") as SpinBox
	var height_input = map_size_dialog.get_node("VBox/GridContainer/HeightInput") as SpinBox
	
	if width_input and height_input:
		map_width = int(width_input.value)
		map_height = int(height_input.value)
		
		if map_display:
			map_display.change_map_size(map_width, map_height, tile_size)

func _on_load_tileset_pressed():
	tileset_dialog.popup_centered(Vector2(800, 600))

func _on_print_stats_pressed():
	if map_display:
		map_display.print_stats()

func _update_ui_state():
	# Update any UI elements based on current state
	pass

# Input handling for keyboard shortcuts
func _input(event: InputEvent):
	if event.is_action_pressed("toggle_generation"):
		generation_toggle.button_pressed = not generation_toggle.button_pressed
	elif event.is_action_pressed("generate_one"):
		_on_generate_one_pressed()
	elif event.is_action_pressed("generate_five"):
		_on_generate_five_pressed()
	elif event.is_action_pressed("reset_map"):
		_on_reset_map_pressed()
