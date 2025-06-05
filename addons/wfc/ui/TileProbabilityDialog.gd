extends AcceptDialog
class_name TileProbabilityDialog

signal probabilities_changed(tile_id: int, new_probabilities: Array)

@onready var tile_preview: TextureRect = $VBox/Header/TilePreview
@onready var tile_label: Label = $VBox/Header/TileLabel
@onready var north_input: SpinBox = $VBox/GridContainer/NorthInput
@onready var east_input: SpinBox = $VBox/GridContainer/EastInput
@onready var south_input: SpinBox = $VBox/GridContainer/SouthInput
@onready var west_input: SpinBox = $VBox/GridContainer/WestInput

var current_tile_id: int = -1
var base_probabilities: Array = [1.0, 1.0, 1.0, 1.0]

func _ready():
	title = "Modify Tile Probabilities"
	size = Vector2i(400, 300)
	
	# Set up spinboxes
	for spinbox in [north_input, east_input, south_input, west_input]:
		spinbox.min_value = 0.0
		spinbox.max_value = 10.0
		spinbox.step = 0.1
		spinbox.value = 1.0

func show_for_tile(tile_id: int, texture: Texture2D, probabilities: Array):
	current_tile_id = tile_id
	base_probabilities = probabilities.duplicate()
	
	# Update UI
	tile_label.text = "Tile %d" % tile_id
	tile_preview.texture = texture
	
	# Set probability values
	if probabilities.size() >= 4:
		north_input.value = probabilities[2]  # North is index 2
		east_input.value = probabilities[1]   # East is index 1
		south_input.value = probabilities[0]  # South is index 0
		west_input.value = probabilities[3]   # West is index 3
	
	popup_centered()

func _on_confirmed():
	var new_probabilities = [
		south_input.value,
		east_input.value,
		north_input.value,
		west_input.value
	]
	
	probabilities_changed.emit(current_tile_id, new_probabilities)

func _on_reset_pressed():
	north_input.value = base_probabilities[2]
	east_input.value = base_probabilities[1]
	south_input.value = base_probabilities[0]
	west_input.value = base_probabilities[3]

func _on_double_pressed():
	north_input.value = min(north_input.value * 2, 10.0)
	east_input.value = min(east_input.value * 2, 10.0)
	south_input.value = min(south_input.value * 2, 10.0)
	west_input.value = min(west_input.value * 2, 10.0)

func _on_halve_pressed():
	north_input.value = north_input.value / 2
	east_input.value = east_input.value / 2
	south_input.value = south_input.value / 2
	west_input.value = west_input.value / 2
