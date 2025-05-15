extends TileMapLayer

@onready var camera = get_parent().get_node("Camera2D")

var zoom_min = 0.5
var zoom_max = 3.0
var zoom_speed = 0.1

var dragging := false

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 1.0 - zoom_speed
			camera.zoom = camera.zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.0 + zoom_speed
			camera.zoom = camera.zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed

	elif event is InputEventMouseMotion and dragging:
		camera.global_position -= event.relative * camera.zoom
