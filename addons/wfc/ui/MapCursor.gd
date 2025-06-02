extends Node2D
class_name MapCursor

signal position_changed(grid_pos: Vector2i)
signal tile_selected(grid_pos: Vector2i)

var grid_position: Vector2i = Vector2i.ZERO
var tile_size: int = 32
var map_width: int = 14
var map_height: int = 14

# Visual properties
var cursor_color: Color = Color(1, 1, 0, 0.8)
var cursor_thickness: float = 3.0
var animation_speed: float = 2.0
var animation_amplitude: float = 5.0

# Animation state
var animation_time: float = 0.0

func _ready():
	# Ensure cursor is drawn on top
	z_index = 10

func _draw():
	# Draw animated cursor border
	var offset = sin(animation_time * animation_speed) * animation_amplitude
	var rect_pos = Vector2(grid_position.x * tile_size, grid_position.y * tile_size)
	var rect_size = Vector2(tile_size, tile_size)
	
	# Outer animated border
	draw_rect(
		Rect2(rect_pos - Vector2(offset, offset), rect_size + Vector2(offset * 2, offset * 2)),
		cursor_color,
		false,
		cursor_thickness
	)
	
	# Inner static border
	draw_rect(
		Rect2(rect_pos, rect_size),
		cursor_color * Color(1, 1, 1, 0.5),
		false,
		cursor_thickness * 0.5
	)
	
	# Corner highlights
	var corner_size = tile_size * 0.2
	var corners = [
		rect_pos,  # Top-left
		rect_pos + Vector2(tile_size - corner_size, 0),  # Top-right
		rect_pos + Vector2(0, tile_size - corner_size),  # Bottom-left
		rect_pos + Vector2(tile_size - corner_size, tile_size - corner_size)  # Bottom-right
	]
	
	for corner in corners:
		draw_rect(
			Rect2(corner, Vector2(corner_size, cursor_thickness)),
			cursor_color,
			true
		)
		draw_rect(
			Rect2(corner, Vector2(cursor_thickness, corner_size)),
			cursor_color,
			true
		)

func _process(delta):
	animation_time += delta
	queue_redraw()

func initialize(width: int, height: int, tile_sz: int):
	map_width = width
	map_height = height
	tile_size = tile_sz
	grid_position = Vector2i(width / 2, height / 2)
	position_changed.emit(grid_position)

func move_to(grid_pos: Vector2i):
	grid_position.x = clamp(grid_pos.x, 0, map_width - 1)
	grid_position.y = clamp(grid_pos.y, 0, map_height - 1)
	
	# Update visual position to match grid position
	queue_redraw()
	
	position_changed.emit(grid_position)

func move_relative(offset: Vector2i):
	move_to(grid_position + offset)

func get_world_position() -> Vector2:
	return Vector2(grid_position.x * tile_size + tile_size / 2, grid_position.y * tile_size + tile_size / 2)

# Input now handled by MapDisplay - this is just the visual cursor