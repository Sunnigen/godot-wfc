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

# Tilemap Analysis UI References (for progress updates)
var current_progress_label: Label
var current_progress_bar: ProgressBar 
var current_analyze_button: Button

func _ready():
	# Connect UI signals
	tileset_dialog.file_selected.connect(_on_tileset_selected)
	
	# Set up file dialog
	tileset_dialog.current_dir = "res://data/generated_tilesets/"
	tileset_dialog.add_filter("*.tres", "Godot Tileset Files")
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

# Tilemap Analysis Dialog Methods
func _on_analyze_tilemap_pressed():
	"""Open the tilemap analysis dialog"""
	var dialog = get_node("TilemapAnalysisDialog")
	if dialog:
		dialog.popup_centered()

func _on_browse_tilemap_pressed():
	"""Open file browser for tilemap selection"""
	var file_dialog = get_node("TilemapAnalysisDialog/FileDialog")
	if file_dialog:
		# Set default directory to input_maps folder
		var input_maps_path = ProjectSettings.globalize_path("res://data/input_maps")
		
		if DirAccess.dir_exists_absolute(input_maps_path):
			file_dialog.set_current_dir(input_maps_path)
		else:
			# Fallback to project root
			file_dialog.set_current_dir(ProjectSettings.globalize_path("res://"))
		
		file_dialog.popup_centered()

func _on_tilemap_file_selected(file_path: String):
	"""Handle tilemap file selection"""
	var file_input = get_node("TilemapAnalysisDialog/VBox/FileSection/FileContainer/FilePathInput")
	var analyze_button = get_node("TilemapAnalysisDialog/VBox/ActionButtons/AnalyzeButton")
	var output_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/OutputNameInput")
	
	if file_input:
		file_input.text = file_path
	
	if analyze_button:
		# Enable analyze button if we have both file and output name
		var has_output_name = output_input and output_input.text.strip_edges().length() > 0
		analyze_button.disabled = not has_output_name
	
	# Auto-populate output name from filename if empty
	if output_input and output_input.text.strip_edges().length() == 0:
		var filename = file_path.get_file().get_basename()
		output_input.text = filename.to_lower()
		if analyze_button:
			analyze_button.disabled = false

func _on_analyze_button_pressed():
	"""Start the tilemap analysis process"""
	var file_input = get_node("TilemapAnalysisDialog/VBox/FileSection/FileContainer/FilePathInput")
	var tile_size_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/TileSizeInput")
	var output_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/OutputNameInput")
	var color_threshold_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/ColorThresholdInput")
	var use_position_check = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/AdjacencyMethodsContainer/UsePositionRulesCheck")
	var use_pixel_check = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/AdjacencyMethodsContainer/UsePixelRulesCheck")
	var progress_label = get_node("TilemapAnalysisDialog/VBox/ProgressSection/ProgressLabel")
	var progress_bar = get_node("TilemapAnalysisDialog/VBox/ProgressSection/ProgressBar")
	var analyze_button = get_node("TilemapAnalysisDialog/VBox/ActionButtons/AnalyzeButton")
	
	if not file_input or not tile_size_input or not output_input or not color_threshold_input or not use_position_check or not use_pixel_check:
		push_error("Missing dialog components")
		return
	
	var file_path = file_input.text.strip_edges()
	var tile_size = int(tile_size_input.value)
	var output_name = output_input.text.strip_edges()
	var color_threshold = float(color_threshold_input.value)
	var use_position_rules = use_position_check.button_pressed
	var use_pixel_rules = use_pixel_check.button_pressed
	
	if file_path.is_empty() or output_name.is_empty():
		if progress_label:
			progress_label.text = "Error: Missing file path or output name"
		return
	
	# Validate adjacency method selection
	if not use_position_rules and not use_pixel_rules:
		if progress_label:
			progress_label.text = "Error: Must select at least one adjacency method"
		return
	
	# Disable analyze button during processing
	if analyze_button:
		analyze_button.disabled = true
	
	# Create and configure analyzer
	var analyzer = TilemapAnalyzer.new()
	
	# Connect signals for progress tracking
	analyzer.progress_updated.connect(_on_analysis_progress)
	analyzer.analysis_complete.connect(_on_analysis_complete)
	analyzer.analysis_failed.connect(_on_analysis_failed)
	
	# Store UI references for updates
	current_progress_label = progress_label
	current_progress_bar = progress_bar
	current_analyze_button = analyze_button
	
	print("Starting tilemap analysis: %s -> %s (threshold: %d, position: %s, pixel: %s)" % [file_path, output_name, color_threshold, use_position_rules, use_pixel_rules])
	
	# Start analysis
	analyzer.analyze_tilemap(file_path, tile_size, output_name, color_threshold, use_position_rules, use_pixel_rules)

# Tilemap Analysis Signal Handlers
func _on_analysis_progress(step: String, percentage: float):
	"""Handle progress updates from analyzer"""
	if current_progress_label:
		current_progress_label.text = step
	if current_progress_bar:
		current_progress_bar.value = percentage

func _on_analysis_complete(tileset: TilesetData):
	"""Handle successful analysis completion"""
	if current_progress_label:
		current_progress_label.text = "Analysis complete! Tileset saved."
	if current_progress_bar:
		current_progress_bar.value = 100.0
	if current_analyze_button:
		current_analyze_button.disabled = false
	
	print("Tilemap analysis completed successfully!")
	print("Generated tileset with %d tiles" % tileset.get_non_blank_tile_ids().size())
	
	# Auto-load the newly generated tileset
	var output_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/OutputNameInput")
	if output_input:
		var output_name = output_input.text.strip_edges()
		var tileset_path = "res://data/generated_tilesets/" + output_name + ".tres"
		
		# Load the tileset into the WFC
		if map_display:
			map_display.load_tileset(tileset_path)
			print("Auto-loaded tileset: " + tileset_path)
	
	# Update progress to show auto-loading completed
	if current_progress_label:
		current_progress_label.text = "Analysis complete! Tileset loaded and ready."

func _on_analysis_failed(error: String):
	"""Handle analysis failure"""
	if current_progress_label:
		current_progress_label.text = "Error: " + error
	if current_progress_bar:
		current_progress_bar.value = 0.0
	if current_analyze_button:
		current_analyze_button.disabled = false
	
	push_error("Tilemap analysis failed: " + error)

func _on_use_pixel_rules_toggled(pressed: bool):
	"""Handle pixel rules checkbox toggle"""
	var color_threshold_input = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/ColorThresholdInput")
	var color_threshold_label = get_node("TilemapAnalysisDialog/VBox/SettingsSection/SettingsGrid/ColorThresholdLabel")
	
	if color_threshold_input:
		color_threshold_input.editable = pressed
		color_threshold_input.modulate = Color.WHITE if pressed else Color(0.7, 0.7, 0.7, 1.0)
	
	if color_threshold_label:
		color_threshold_label.modulate = Color.WHITE if pressed else Color(0.7, 0.7, 0.7, 1.0)

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
	elif event.is_action_pressed("ui_accept"):  # Enter key
		# Force visual refresh for debugging
		if map_display:
			map_display.force_visual_refresh()
